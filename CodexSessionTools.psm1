function Find-CodexSession {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string]$Query,

        [switch]$ExactTitle
    )

    $ErrorActionPreference = "Stop"

    $CodexHome = if ($env:CODEX_HOME) {
        [IO.Path]::GetFullPath($env:CODEX_HOME)
    }
    else {
        Join-Path $HOME ".codex"
    }

    $Map = @{}

    # =========================================================
    # 1. Core: session_index.jsonl
    # =========================================================

    $IndexPath = Join-Path $CodexHome "session_index.jsonl"

    if (Test-Path $IndexPath) {

        foreach ($line in Get-Content $IndexPath -Encoding UTF8) {

            try {
                $obj = $line | ConvertFrom-Json
            }
            catch {
                continue
            }

            if (-not $obj.id) {
                continue
            }

            $id = [string]$obj.id

            if (-not $Map.ContainsKey($id)) {
                $Map[$id] = [ordered]@{
                    UUID    = $id
                    Title   = $null
                    Core    = $false
                    Desktop = $false
                    Cwd     = $null
                }
            }

            $Map[$id].Core = $true

            if ($obj.thread_name) {
                $Map[$id].Title = [string]$obj.thread_name
            }
        }
    }

    # =========================================================
    # 2. Desktop: local_thread_catalog
    # =========================================================

    if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
        throw "Python is required to inspect the Codex Desktop catalog."
    }

    $CatalogDb = Join-Path $CodexHome "sqlite\codex-dev.db"

    if (Test-Path $CatalogDb) {

        $env:CODEX_FIND_DB = $CatalogDb

        $DesktopJson = @'
import json
import os
import sqlite3
from pathlib import Path

db = Path(os.environ["CODEX_FIND_DB"])

uri = db.resolve().as_uri() + "?mode=ro"
con = sqlite3.connect(uri, uri=True)
cur = con.cursor()

exists = cur.execute(
    """
    SELECT 1
    FROM sqlite_master
    WHERE type='table'
      AND name='local_thread_catalog'
    """
).fetchone()

result = []

if exists:

    columns = [
        row[1]
        for row in cur.execute(
            'PRAGMA table_info("local_thread_catalog")'
        )
    ]

    if "thread_id" in columns:

        if "display_title" in columns:
            title_col = "display_title"
        elif "title" in columns:
            title_col = "title"
        else:
            title_col = None

        cwd_col = "cwd" if "cwd" in columns else None

        select_cols = ["thread_id"]

        if title_col:
            select_cols.append(title_col)

        if cwd_col:
            select_cols.append(cwd_col)

        sql = (
            "SELECT "
            + ", ".join(
                '"' + c.replace('"', '""') + '"'
                for c in select_cols
            )
            + " FROM local_thread_catalog"
        )

        for row in cur.execute(sql):

            item = {
                "uuid": row[0],
                "title": None,
                "cwd": None
            }

            pos = 1

            if title_col:
                item["title"] = row[pos]
                pos += 1

            if cwd_col:
                item["cwd"] = row[pos]

            result.append(item)

con.close()

print(json.dumps(result, ensure_ascii=True))
'@ | python -

        if ($LASTEXITCODE -ne 0) {
            throw "Failed to read Codex Desktop catalog."
        }

        if ($DesktopJson) {

            $DesktopRows = $DesktopJson | ConvertFrom-Json

            foreach ($row in @($DesktopRows)) {

                if (-not $row.uuid) {
                    continue
                }

                $id = [string]$row.uuid

                if (-not $Map.ContainsKey($id)) {
                    $Map[$id] = [ordered]@{
                        UUID    = $id
                        Title   = $null
                        Core    = $false
                        Desktop = $false
                        Cwd     = $null
                    }
                }

                $Map[$id].Desktop = $true

                if ($row.title) {
                    $Map[$id].Title = [string]$row.title
                }

                if ($row.cwd) {
                    $Map[$id].Cwd = [string]$row.cwd
                }
            }
        }
    }

    # =========================================================
    # 3. Build unified results
    # =========================================================

    $Results = foreach ($entry in $Map.Values) {

        $Status = if ($entry.Core -and $entry.Desktop) {
            "Core+Desktop"
        }
        elseif ($entry.Core) {
            "CoreOnly"
        }
        elseif ($entry.Desktop) {
            "DesktopOnly (Ghost)"
        }
        else {
            "Unknown"
        }

        [pscustomobject]@{
            Status  = $Status
            Title   = $entry.Title
            UUID    = $entry.UUID
            Core    = $entry.Core
            Desktop = $entry.Desktop
            Cwd     = $entry.Cwd
        }
    }

    # =========================================================
    # 4. Filter
    # =========================================================

    if ($Query) {

        if (
            $Query -match
            '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
        ) {
            $Results = $Results |
                Where-Object {
                    $_.UUID -eq $Query
                }
        }
        elseif ($ExactTitle) {
            $Results = $Results |
                Where-Object {
                    $_.Title -eq $Query
                }
        }
        else {
            $Results = $Results |
                Where-Object {
                    $_.Title -like "*$Query*"
                }
        }
    }

    $Results |
        Sort-Object Title, UUID
}


function Remove-CodexSessionHard {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidatePattern(
            '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
        )]
        [string]$Uuid
    )

    $ErrorActionPreference = "Stop"

    $CodexHome = if ($env:CODEX_HOME) {
        [IO.Path]::GetFullPath($env:CODEX_HOME)
    }
    else {
        Join-Path $HOME ".codex"
    }

    Write-Host ""
    Write-Host "Target UUID : $Uuid"
    Write-Host "CODEX_HOME  : $CodexHome"
    Write-Host ""

    # =========================================================
    # 1. Safety gate
    # =========================================================

    $running = Get-Process -ErrorAction SilentlyContinue |
        Where-Object {
            $_.ProcessName -like "*Codex*" -or
            $_.ProcessName -like "*ChatGPT*"
        }

    if ($running) {

        Write-Host "Running Codex/ChatGPT processes:" `
            -ForegroundColor Yellow

        $running |
            Select-Object ProcessName, Id, Path |
            Format-Table

        throw "ABORTED: fully close Codex/ChatGPT Desktop first."
    }

    if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
        throw "ABORTED: Python was not found."
    }

    if (-not (Get-Command codex -ErrorAction SilentlyContinue)) {
        throw "ABORTED: codex CLI was not found."
    }

    $env:CODEX_DELETE_UUID = $Uuid
    $env:CODEX_DELETE_HOME = $CodexHome

    # =========================================================
    # 2. Determine whether Core session exists
    # =========================================================

    Write-Host "[1/6] Inspecting Core session state..."

    $RolloutMatches = @(
        Get-ChildItem `
            (Join-Path $CodexHome "sessions"),
            (Join-Path $CodexHome "archived_sessions") `
            -Recurse `
            -File `
            -Filter "*$Uuid*" `
            -ErrorAction SilentlyContinue
    )

    $IndexPath = Join-Path $CodexHome "session_index.jsonl"

    $IndexMatch = $false

    if (Test-Path $IndexPath) {
        $IndexMatch = [bool](
            Select-String `
                -LiteralPath $IndexPath `
                -Pattern $Uuid `
                -Encoding UTF8 `
                -Quiet
        )
    }

    $CoreDbCheck = @'
import os
import sqlite3
from pathlib import Path

uuid = os.environ["CODEX_DELETE_UUID"]
home = Path(os.environ["CODEX_DELETE_HOME"])

found = []

for db in home.glob("state_*.sqlite"):

    uri = db.resolve().as_uri() + "?mode=ro"

    con = sqlite3.connect(uri, uri=True)
    cur = con.cursor()

    tables = [
        r[0]
        for r in cur.execute(
            "SELECT name FROM sqlite_master WHERE type='table'"
        )
    ]

    for table in tables:

        qt = '"' + table.replace('"', '""') + '"'

        columns = [
            r[1]
            for r in cur.execute(
                f"PRAGMA table_info({qt})"
            )
        ]

        for col in columns:

            qc = '"' + col.replace('"', '""') + '"'

            try:
                row = cur.execute(
                    f"""
                    SELECT 1
                    FROM {qt}
                    WHERE instr(
                        CAST({qc} AS TEXT),
                        ?
                    ) > 0
                    LIMIT 1
                    """,
                    (uuid,)
                ).fetchone()

                if row:
                    found.append(
                        f"{db.name}:{table}.{col}"
                    )

            except sqlite3.Error:
                pass

    con.close()

if found:
    for item in found:
        print("FOUND:" + item)
else:
    print("CLEAN")
'@ | python -

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to inspect Core SQLite state."
    }

    $CoreDbDirty = @(
        $CoreDbCheck |
            Where-Object {
                $_ -like "FOUND:*"
            }
    ).Count -gt 0

    $CoreExists = (
        $RolloutMatches.Count -gt 0 -or
        $IndexMatch -or
        $CoreDbDirty
    )

    if ($CoreExists) {
        Write-Host "Core session exists."
    }
    else {
        Write-Host "Core session already absent."
    }

    # =========================================================
    # 3. Official deletion when Core exists
    # =========================================================

    Write-Host ""
    Write-Host "[2/6] Core deletion..."

    if ($CoreExists) {

        & codex delete --force $Uuid

        $DeleteExitCode = $LASTEXITCODE

        if ($DeleteExitCode -eq 0) {
            Write-Host "Official deletion returned success."
        }
        else {
            Write-Warning (
                "codex delete returned exit code " +
                "$DeleteExitCode. Actual state will now be verified."
            )
        }
    }
    else {
        Write-Host "Skipped: no Core session exists."
    }

    # =========================================================
    # 4. Verify Core is clean
    # =========================================================

    Write-Host ""
    Write-Host "[3/6] Verifying Core state..."

    $RemainingRollouts = @(
        Get-ChildItem `
            (Join-Path $CodexHome "sessions"),
            (Join-Path $CodexHome "archived_sessions") `
            -Recurse `
            -File `
            -Filter "*$Uuid*" `
            -ErrorAction SilentlyContinue
    )

    $RemainingIndex = $false

    if (Test-Path $IndexPath) {
        $RemainingIndex = [bool](
            Select-String `
                -LiteralPath $IndexPath `
                -Pattern $Uuid `
                -Encoding UTF8 `
                -Quiet
        )
    }

    $RemainingCoreDb = @'
import os
import sqlite3
from pathlib import Path

uuid = os.environ["CODEX_DELETE_UUID"]
home = Path(os.environ["CODEX_DELETE_HOME"])

found = []

for db in home.glob("state_*.sqlite"):

    uri = db.resolve().as_uri() + "?mode=ro"

    con = sqlite3.connect(uri, uri=True)
    cur = con.cursor()

    tables = [
        r[0]
        for r in cur.execute(
            "SELECT name FROM sqlite_master WHERE type='table'"
        )
    ]

    for table in tables:

        qt = '"' + table.replace('"', '""') + '"'

        columns = [
            r[1]
            for r in cur.execute(
                f"PRAGMA table_info({qt})"
            )
        ]

        for col in columns:

            qc = '"' + col.replace('"', '""') + '"'

            try:
                row = cur.execute(
                    f"""
                    SELECT 1
                    FROM {qt}
                    WHERE instr(
                        CAST({qc} AS TEXT),
                        ?
                    ) > 0
                    LIMIT 1
                    """,
                    (uuid,)
                ).fetchone()

                if row:
                    found.append(
                        f"{db.name}:{table}.{col}"
                    )

            except sqlite3.Error:
                pass

    con.close()

for item in found:
    print(item)
'@ | python -

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to verify Core SQLite state."
    }

    if (
        $RemainingRollouts.Count -gt 0 -or
        $RemainingIndex -or
        @($RemainingCoreDb).Count -gt 0
    ) {

        Write-Host ""
        Write-Host "Core state is NOT clean." `
            -ForegroundColor Red

        if ($RemainingRollouts.Count -gt 0) {
            Write-Host "Remaining rollout files:"

            $RemainingRollouts |
                Select-Object FullName |
                Format-Table
        }

        if ($RemainingIndex) {
            Write-Host "UUID remains in session_index.jsonl."
        }

        if (@($RemainingCoreDb).Count -gt 0) {
            Write-Host "UUID remains in Core SQLite:"
            $RemainingCoreDb
        }

        throw (
            "ABORTED: Core session still exists. " +
            "Desktop metadata was NOT modified."
        )
    }

    Write-Host "Core session state: clean"

    # =========================================================
    # 5. Clean global-state UUID references
    # =========================================================

    Write-Host ""
    Write-Host "[4/6] Cleaning Desktop global metadata..."

    $GlobalFiles = @(
        (Join-Path $CodexHome ".codex-global-state.json"),
        (Join-Path $CodexHome ".codex-global-state.json.bak")
    )

    foreach ($GlobalFile in $GlobalFiles) {

        if (-not (Test-Path $GlobalFile)) {
            continue
        }

        $env:CODEX_GLOBAL_FILE = $GlobalFile

        @'
import json
import os
import shutil
from datetime import datetime
from pathlib import Path

uuid = os.environ["CODEX_DELETE_UUID"]
path = Path(os.environ["CODEX_GLOBAL_FILE"])

with path.open("r", encoding="utf-8") as f:
    data = json.load(f)

removed = 0

def clean(obj):
    global removed

    if isinstance(obj, dict):

        for key in list(obj.keys()):

            value = obj[key]

            if uuid in str(key):
                del obj[key]
                removed += 1
                continue

            if isinstance(value, str) and uuid in value:
                del obj[key]
                removed += 1
                continue

            clean(value)

    elif isinstance(obj, list):

        new_values = []

        for value in obj:

            if isinstance(value, str) and uuid in value:
                removed += 1
                continue

            clean(value)
            new_values.append(value)

        obj[:] = new_values

clean(data)

if removed == 0:
    print(f"GLOBAL_CLEAN:{path}")
    raise SystemExit(0)

stamp = datetime.now().strftime(
    "%Y%m%d-%H%M%S-%f"
)

backup = path.with_name(
    path.name + f".predelete-{stamp}"
)

shutil.copy2(path, backup)

temp = path.with_name(
    path.name + ".tmp"
)

with temp.open(
    "w",
    encoding="utf-8",
    newline="\n"
) as f:
    json.dump(
        data,
        f,
        ensure_ascii=False,
        separators=(",", ":")
    )

temp.replace(path)

print(f"GLOBAL_REMOVED:{removed}:{path}")
print(f"GLOBAL_BACKUP:{backup}")
'@ | python -

        if ($LASTEXITCODE -ne 0) {
            throw (
                "Failed to clean global-state metadata: " +
                "$GlobalFile"
            )
        }
    }

    # =========================================================
    # 6. Clean Desktop catalog
    # =========================================================

    Write-Host ""
    Write-Host "[5/6] Cleaning Desktop thread catalog..."

    $CatalogDb = Join-Path $CodexHome "sqlite\codex-dev.db"

    if (Test-Path $CatalogDb) {

        $env:CODEX_CATALOG_DB = $CatalogDb

        @'
import os
import sqlite3
from datetime import datetime
from pathlib import Path

uuid = os.environ["CODEX_DELETE_UUID"]
db = Path(os.environ["CODEX_CATALOG_DB"])

con = sqlite3.connect(db)
cur = con.cursor()

exists = cur.execute(
    """
    SELECT 1
    FROM sqlite_master
    WHERE type='table'
      AND name='local_thread_catalog'
    """
).fetchone()

if not exists:
    con.close()
    print("CATALOG_TABLE_NOT_FOUND")
    raise SystemExit(0)

columns = {
    row[1]
    for row in cur.execute(
        'PRAGMA table_info("local_thread_catalog")'
    )
}

if "thread_id" not in columns:
    con.close()

    raise SystemExit(
        "ABORTED: local_thread_catalog "
        "does not contain thread_id."
    )

rows = cur.execute(
    """
    SELECT rowid, *
    FROM local_thread_catalog
    WHERE thread_id = ?
    """,
    (uuid,)
).fetchall()

print("Catalog matching rows:", len(rows))

if len(rows) == 0:
    con.close()
    print("Desktop catalog already clean.")
    raise SystemExit(0)

if len(rows) != 1:
    con.close()

    raise SystemExit(
        f"ABORTED: expected exactly 1 matching "
        f"catalog row, found {len(rows)}."
    )

stamp = datetime.now().strftime(
    "%Y%m%d-%H%M%S-%f"
)

backup = db.with_name(
    f"codex-dev.backup-{stamp}.db"
)

bak = sqlite3.connect(backup)

try:
    con.backup(bak)
finally:
    bak.close()

print("Catalog backup:", backup)

con.execute("BEGIN IMMEDIATE")

try:

    result = con.execute(
        """
        DELETE FROM local_thread_catalog
        WHERE thread_id = ?
        """,
        (uuid,)
    )

    if result.rowcount != 1:
        raise RuntimeError(
            f"Expected exactly 1 deleted row, "
            f"got {result.rowcount}."
        )

    con.commit()

except Exception:
    con.rollback()
    con.close()
    raise

remaining = con.execute(
    """
    SELECT COUNT(*)
    FROM local_thread_catalog
    WHERE thread_id = ?
    """,
    (uuid,)
).fetchone()[0]

con.close()

if remaining != 0:
    raise SystemExit(
        "Catalog verification failed."
    )

print("Deleted exactly 1 Desktop catalog row.")
'@ | python -

        if ($LASTEXITCODE -ne 0) {
            throw "Desktop catalog cleanup failed."
        }
    }
    else {
        Write-Host "Desktop catalog database not found."
    }

    # =========================================================
    # 7. Final verification
    # =========================================================

    Write-Host ""
    Write-Host "[6/6] Final UUID verification..."

    $FinalResult = @'
import os
import sqlite3
from pathlib import Path

uuid = os.environ["CODEX_DELETE_UUID"]
home = Path(os.environ["CODEX_DELETE_HOME"])

problems = []

index = home / "session_index.jsonl"

if index.exists():

    text = index.read_text(
        encoding="utf-8",
        errors="ignore"
    )

    if uuid in text:
        problems.append(
            "session_index.jsonl"
        )

for root_name in (
    "sessions",
    "archived_sessions"
):

    root = home / root_name

    if not root.exists():
        continue

    for path in root.rglob("*"):

        if (
            path.is_file()
            and uuid in path.name
        ):
            problems.append(
                str(path)
            )

for db in home.glob("state_*.sqlite"):

    uri = db.resolve().as_uri() + "?mode=ro"

    con = sqlite3.connect(
        uri,
        uri=True
    )

    cur = con.cursor()

    tables = [
        r[0]
        for r in cur.execute(
            "SELECT name "
            "FROM sqlite_master "
            "WHERE type='table'"
        )
    ]

    db_found = False

    for table in tables:

        qt = '"' + table.replace('"', '""') + '"'

        columns = [
            r[1]
            for r in cur.execute(
                f"PRAGMA table_info({qt})"
            )
        ]

        for col in columns:

            qc = '"' + col.replace('"', '""') + '"'

            try:

                row = cur.execute(
                    f"""
                    SELECT 1
                    FROM {qt}
                    WHERE instr(
                        CAST({qc} AS TEXT),
                        ?
                    ) > 0
                    LIMIT 1
                    """,
                    (uuid,)
                ).fetchone()

                if row:

                    problems.append(
                        f"{db.name}:{table}.{col}"
                    )

                    db_found = True
                    break

            except sqlite3.Error:
                pass

        if db_found:
            break

    con.close()

for name in (
    ".codex-global-state.json",
    ".codex-global-state.json.bak"
):

    path = home / name

    if not path.exists():
        continue

    text = path.read_text(
        encoding="utf-8",
        errors="ignore"
    )

    if uuid in text:
        problems.append(name)

db = home / "sqlite" / "codex-dev.db"

if db.exists():

    uri = db.resolve().as_uri() + "?mode=ro"

    con = sqlite3.connect(
        uri,
        uri=True
    )

    cur = con.cursor()

    exists = cur.execute(
        """
        SELECT 1
        FROM sqlite_master
        WHERE type='table'
          AND name='local_thread_catalog'
        """
    ).fetchone()

    if exists:

        columns = {
            row[1]
            for row in cur.execute(
                'PRAGMA table_info("local_thread_catalog")'
            )
        }

        if "thread_id" in columns:

            row = cur.execute(
                """
                SELECT 1
                FROM local_thread_catalog
                WHERE thread_id = ?
                LIMIT 1
                """,
                (uuid,)
            ).fetchone()

            if row:
                problems.append(
                    "codex-dev.db:"
                    "local_thread_catalog"
                )

    con.close()

if problems:

    print("DIRTY")

    for problem in problems:
        print(problem)

else:
    print("CLEAN")
'@ | python -

    if ($LASTEXITCODE -ne 0) {
        throw "Final verification failed to run."
    }

    $FinalLines = @($FinalResult)

    if (-not ($FinalLines -contains "CLEAN")) {

        Write-Host ""
        Write-Host "FINAL VERIFICATION FAILED" `
            -ForegroundColor Red

        $FinalLines

        throw (
            "Target UUID still exists in active " +
            "Codex state."
        )
    }

    Write-Host ""
    Write-Host "SUCCESS" `
        -ForegroundColor Green

    Write-Host ""
    Write-Host "Target UUID completely removed:"
    Write-Host "  $Uuid"
    Write-Host ""

    Write-Host "Core session state : clean"
    Write-Host "Global UI metadata : clean"
    Write-Host "Desktop catalog    : clean"
}

function Test-CodexBatchPrerequisites {
    [CmdletBinding()]
    param()

    $CodexHome = if ($env:CODEX_HOME) {
        [IO.Path]::GetFullPath($env:CODEX_HOME)
    }
    else {
        Join-Path $HOME ".codex"
    }

    $running = Get-Process -ErrorAction SilentlyContinue |
        Where-Object {
            $_.ProcessName -like "*Codex*" -or
            $_.ProcessName -like "*ChatGPT*"
        }

    if ($running) {
        Write-Host ""
        Write-Host "Running Codex/ChatGPT processes:" -ForegroundColor Yellow
        $running |
            Select-Object ProcessName, Id, Path |
            Format-Table |
            Out-Host
        throw "ABORTED: fully close Codex/ChatGPT Desktop first."
    }

    if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
        throw "ABORTED: Python was not found."
    }

    if (-not (Get-Command codex -ErrorAction SilentlyContinue)) {
        throw "ABORTED: codex CLI was not found."
    }

    return $CodexHome
}


function Get-CodexSessionBatchSnapshot {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Uuid,

        [Parameter(Mandatory = $true)]
        [string]$CodexHome
    )

    $ErrorActionPreference = "Stop"
    $Map = @{}

    foreach ($id in $Uuid) {
        $key = $id.ToLowerInvariant()
        $Map[$key] = [ordered]@{
            UUID       = $id
            Title      = $null
            Core       = $false
            Desktop    = $false
            Cwd        = $null
            CoreSource = @()
        }
    }

    # 1. Core: session_index.jsonl
    $IndexPath = Join-Path $CodexHome "session_index.jsonl"

    if (Test-Path $IndexPath) {
        foreach ($line in Get-Content $IndexPath -Encoding UTF8) {
            try {
                $obj = $line | ConvertFrom-Json
            }
            catch {
                continue
            }

            if (-not $obj.id) {
                continue
            }

            $key = ([string]$obj.id).ToLowerInvariant()

            if (-not $Map.ContainsKey($key)) {
                continue
            }

            $Map[$key].Core = $true
            $Map[$key].CoreSource += "session_index.jsonl"

            if ($obj.thread_name) {
                $Map[$key].Title = [string]$obj.thread_name
            }
        }
    }

    # 2. Core: rollout files. Each tree is enumerated once.
    $RolloutRoots = @(
        (Join-Path $CodexHome "sessions"),
        (Join-Path $CodexHome "archived_sessions")
    )
    $Targets = @($Map.Keys)

    foreach ($root in $RolloutRoots) {
        if (-not (Test-Path $root)) {
            continue
        }

        foreach ($file in Get-ChildItem $root -Recurse -File -ErrorAction SilentlyContinue) {
            foreach ($key in $Targets) {
                if (
                    $file.Name.IndexOf(
                        $key,
                        [StringComparison]::OrdinalIgnoreCase
                    ) -ge 0
                ) {
                    $Map[$key].Core = $true

                    if ($Map[$key].CoreSource -notcontains "rollout") {
                        $Map[$key].CoreSource += "rollout"
                    }
                }
            }
        }
    }

    # 3. Core SQLite + Desktop catalog in one Python invocation.
    $TargetFile = New-TemporaryFile

    try {
        $TargetJson = ConvertTo-Json -InputObject @($Uuid) -Compress
        Set-Content -LiteralPath $TargetFile.FullName -Value $TargetJson -Encoding UTF8

        $BatchInspectPython = @'
import json
import sqlite3
import sys
from pathlib import Path

with open(sys.argv[1], "r", encoding="utf-8-sig") as f:
    raw_targets = json.load(f)

if isinstance(raw_targets, str):
    raw_targets = [raw_targets]

targets = [str(x).lower() for x in raw_targets]
target_set = set(targets)
home = Path(sys.argv[2])
core_db = set()
desktop = []

for db in home.glob("state_*.sqlite"):
    try:
        uri = db.resolve().as_uri() + "?mode=ro"
        con = sqlite3.connect(uri, uri=True)
    except sqlite3.Error:
        continue

    try:
        cur = con.cursor()
        tables = [
            row[0]
            for row in cur.execute(
                "SELECT name FROM sqlite_master WHERE type='table'"
            )
        ]
        unresolved = target_set - core_db

        for table in tables:
            if not unresolved:
                break

            qt = '"' + table.replace('"', '""') + '"'

            try:
                columns = [
                    row[1]
                    for row in cur.execute(f"PRAGMA table_info({qt})")
                ]
            except sqlite3.Error:
                continue

            for col in columns:
                if not unresolved:
                    break

                qc = '"' + col.replace('"', '""') + '"'

                for uuid in list(unresolved):
                    try:
                        row = cur.execute(
                            f"""
                            SELECT 1
                            FROM {qt}
                            WHERE instr(
                                lower(CAST({qc} AS TEXT)),
                                ?
                            ) > 0
                            LIMIT 1
                            """,
                            (uuid,)
                        ).fetchone()
                    except sqlite3.Error:
                        continue

                    if row:
                        core_db.add(uuid)
                        unresolved.discard(uuid)
    finally:
        con.close()

catalog_db = home / "sqlite" / "codex-dev.db"

if catalog_db.exists():
    try:
        uri = catalog_db.resolve().as_uri() + "?mode=ro"
        con = sqlite3.connect(uri, uri=True)
    except sqlite3.Error:
        con = None

    if con is not None:
        try:
            cur = con.cursor()
            exists = cur.execute(
                """
                SELECT 1
                FROM sqlite_master
                WHERE type='table'
                  AND name='local_thread_catalog'
                """
            ).fetchone()

            if exists:
                columns = [
                    row[1]
                    for row in cur.execute(
                        'PRAGMA table_info("local_thread_catalog")'
                    )
                ]

                if "thread_id" in columns:
                    if "display_title" in columns:
                        title_col = "display_title"
                    elif "title" in columns:
                        title_col = "title"
                    else:
                        title_col = None

                    cwd_col = "cwd" if "cwd" in columns else None
                    select_cols = ["thread_id"]

                    if title_col:
                        select_cols.append(title_col)
                    if cwd_col:
                        select_cols.append(cwd_col)

                    sql = (
                        "SELECT "
                        + ", ".join(
                            '"' + c.replace('"', '""') + '"'
                            for c in select_cols
                        )
                        + " FROM local_thread_catalog"
                    )

                    for row in cur.execute(sql):
                        if row[0] is None:
                            continue

                        uuid = str(row[0]).lower()
                        if uuid not in target_set:
                            continue

                        item = {
                            "uuid": uuid,
                            "title": None,
                            "cwd": None,
                        }
                        pos = 1

                        if title_col:
                            item["title"] = row[pos]
                            pos += 1
                        if cwd_col:
                            item["cwd"] = row[pos]

                        desktop.append(item)
        finally:
            con.close()

print(json.dumps({
    "core_db": sorted(core_db),
    "desktop": desktop,
}, ensure_ascii=True))
'@

        $InspectionJson = & python -c `
            $BatchInspectPython `
            $TargetFile.FullName `
            $CodexHome

        if ($LASTEXITCODE -ne 0) {
            throw "Failed to inspect batch Core/Desktop state."
        }

        if (-not $InspectionJson) {
            throw "Batch inspection returned no data."
        }

        $Inspection = $InspectionJson | ConvertFrom-Json

        foreach ($id in @($Inspection.core_db)) {
            $key = ([string]$id).ToLowerInvariant()

            if ($Map.ContainsKey($key)) {
                $Map[$key].Core = $true
                if ($Map[$key].CoreSource -notcontains "state_*.sqlite") {
                    $Map[$key].CoreSource += "state_*.sqlite"
                }
            }
        }

        foreach ($row in @($Inspection.desktop)) {
            if (-not $row.uuid) {
                continue
            }

            $key = ([string]$row.uuid).ToLowerInvariant()

            if (-not $Map.ContainsKey($key)) {
                continue
            }

            $Map[$key].Desktop = $true

            if ($row.title) {
                $Map[$key].Title = [string]$row.title
            }
            if ($row.cwd) {
                $Map[$key].Cwd = [string]$row.cwd
            }
        }
    }
    finally {
        Remove-Item -LiteralPath $TargetFile.FullName -Force -ErrorAction SilentlyContinue
    }

    # 4. Preserve the stable, de-duplicated input order.
    foreach ($id in $Uuid) {
        $entry = $Map[$id.ToLowerInvariant()]

        $Status = if ($entry.Core -and $entry.Desktop) {
            "Core+Desktop"
        }
        elseif ($entry.Core) {
            "CoreOnly"
        }
        elseif ($entry.Desktop) {
            "DesktopOnly"
        }
        else {
            "Missing"
        }

        [pscustomobject]@{
            Title      = $entry.Title
            UUID       = $entry.UUID
            Status     = $Status
            Core       = [bool]$entry.Core
            Desktop    = [bool]$entry.Desktop
            Cwd        = $entry.Cwd
            CoreSource = @($entry.CoreSource)
        }
    }
}


function Remove-CodexSessionsHard {
    [CmdletBinding(
        SupportsShouldProcess = $true,
        ConfirmImpact = 'High'
    )]
    param(
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true
        )]
        [AllowNull()]
        [AllowEmptyString()]
        [string[]]$Uuid
    )

    begin {
        $ErrorActionPreference = "Stop"
        $Collected = [System.Collections.Generic.List[string]]::new()
    }

    process {
        foreach ($item in @($Uuid)) {
            $Collected.Add($item)
        }
    }

    end {
        $UuidPattern = (
            '^[0-9a-fA-F]{8}-' +
            '[0-9a-fA-F]{4}-' +
            '[0-9a-fA-F]{4}-' +
            '[0-9a-fA-F]{4}-' +
            '[0-9a-fA-F]{12}$'
        )

        if ($Collected.Count -eq 0) {
            throw "ABORTED: no UUIDs were supplied."
        }

        $Invalid = [System.Collections.Generic.List[string]]::new()
        $Normalized = [System.Collections.Generic.List[string]]::new()
        $Seen = [System.Collections.Generic.HashSet[string]]::new(
            [StringComparer]::OrdinalIgnoreCase
        )

        foreach ($raw in $Collected) {
            if ([string]::IsNullOrWhiteSpace($raw)) {
                $Invalid.Add("<empty>")
                continue
            }

            $candidate = $raw.Trim()

            if ($candidate -notmatch $UuidPattern) {
                $Invalid.Add($candidate)
                continue
            }

            $candidate = $candidate.ToLowerInvariant()

            if ($Seen.Add($candidate)) {
                $Normalized.Add($candidate)
            }
        }

        if ($Invalid.Count -gt 0) {
            Write-Host ""
            Write-Host "BATCH VALIDATION FAILED" -ForegroundColor Red
            Write-Host ""
            Write-Host "Invalid UUID input(s):"

            foreach ($item in $Invalid) {
                Write-Host "  $item"
            }

            Write-Host ""
            Write-Host "No sessions were deleted."
            throw "ABORTED: one or more UUID inputs are invalid."
        }

        if ($Normalized.Count -eq 0) {
            throw "ABORTED: no valid UUIDs remain after validation."
        }

        Write-Host ""
        Write-Host "[Batch 1/4] Checking prerequisites..."
        $CodexHome = Test-CodexBatchPrerequisites
        Write-Host "CODEX_HOME  : $CodexHome"

        Write-Host ""
        Write-Host "[Batch 2/4] Preflighting all targets..."

        $Plan = @(
            Get-CodexSessionBatchSnapshot `
                -Uuid @($Normalized) `
                -CodexHome $CodexHome
        )

        $Missing = @(
            $Plan |
                Where-Object {
                    -not $_.Core -and -not $_.Desktop
                }
        )

        if ($Missing.Count -gt 0) {
            Write-Host ""
            Write-Host "BATCH PREFLIGHT FAILED" -ForegroundColor Red
            Write-Host ""
            Write-Host "The following UUID(s) do not exist in Core or Desktop:"

            $Missing |
                Select-Object UUID |
                Format-Table |
                Out-Host

            Write-Host "No sessions were deleted."
            throw (
                "ABORTED: one or more target UUIDs do not exist. " +
                "No deletion was started."
            )
        }

        Write-Host ""
        Write-Host "[Batch 3/4] Deletion plan"
        Write-Host ""
        Write-Host "Unique targets : $($Plan.Count)"
        Write-Host ""

        $DisplayPlan = $Plan |
            Select-Object `
                @{Name = 'Title'; Expression = {
                    if ($_.Title) { $_.Title } else { '<untitled>' }
                }},
                UUID,
                Status

        $DisplayPlan |
            Format-Table -AutoSize |
            Out-Host

        $TargetDescription = "$($Plan.Count) Codex session(s) under $CodexHome"

        if (-not $PSCmdlet.ShouldProcess(
            $TargetDescription,
            "Permanently delete the preflighted batch"
        )) {
            Write-Host ""
            Write-Host "No sessions were deleted."
            return
        }

        Write-Host ""
        Write-Host "[Batch 4/4] Sequential deletion..."
        Write-Host ""

        $Results = [System.Collections.Generic.List[object]]::new()
        $Failure = $null

        for ($i = 0; $i -lt $Plan.Count; $i++) {
            $item = $Plan[$i]

            Write-Host (
                "--- [{0}/{1}] {2} ---" -f `
                    ($i + 1),
                    $Plan.Count,
                    $item.UUID
            )

            try {
                Remove-CodexSessionHard -Uuid $item.UUID

                $Results.Add(
                    [pscustomobject]@{
                        Title  = $item.Title
                        UUID   = $item.UUID
                        Result = "Completed"
                        Error  = $null
                    }
                )
            }
            catch {
                $Failure = $_

                $Results.Add(
                    [pscustomobject]@{
                        Title  = $item.Title
                        UUID   = $item.UUID
                        Result = "Failed"
                        Error  = $_.Exception.Message
                    }
                )

                for ($j = $i + 1; $j -lt $Plan.Count; $j++) {
                    $pending = $Plan[$j]
                    $Results.Add(
                        [pscustomobject]@{
                            Title  = $pending.Title
                            UUID   = $pending.UUID
                            Result = "NotRun"
                            Error  = $null
                        }
                    )
                }

                break
            }

            Write-Host ""
        }

        Write-Host ""
        Write-Host "BATCH RESULT"
        Write-Host ""

        $Results |
            Select-Object `
                @{Name = 'Title'; Expression = {
                    if ($_.Title) { $_.Title } else { '<untitled>' }
                }},
                UUID,
                Result |
            Format-Table -AutoSize |
            Out-Host

        $CompletedCount = @(
            $Results | Where-Object Result -eq "Completed"
        ).Count
        $FailedCount = @(
            $Results | Where-Object Result -eq "Failed"
        ).Count
        $NotRunCount = @(
            $Results | Where-Object Result -eq "NotRun"
        ).Count

        Write-Host "Completed : $CompletedCount"
        Write-Host "Failed    : $FailedCount"
        Write-Host "Not run   : $NotRunCount"

        if ($Failure) {
            Write-Host ""
            Write-Host "Batch deletion stopped after the first failure." -ForegroundColor Red
            Write-Host (
                "This batch is not transactional; completed " +
                "deletions were not rolled back."
            )
            Write-Host ""
            Write-Host "Failure: $($Failure.Exception.Message)"
            throw $Failure
        }

        Write-Host ""
        Write-Host "BATCH SUCCESS" -ForegroundColor Green
        Write-Host "All preflighted sessions were removed successfully."
    }
}


Export-ModuleMember `
    -Function `
        Find-CodexSession, `
        Remove-CodexSessionHard, `
        Remove-CodexSessionsHard
