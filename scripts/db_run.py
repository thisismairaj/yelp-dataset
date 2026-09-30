"""Run SQL against Databricks (Trial workspace) via the CLI's Statement Execution API.
Same script as D:\\data-lab2\\scripts\\db_run.py, just pointed at the Trial profile and
its warehouse instead of Free Edition's - copied rather than imported across repos so
each repo stays self-contained (no cross-repo path dependency).

Usage: python db_run.py "<sql>;<sql>;..."   or   python db_run.py path/to/file.sql
"""
import sys, os, json, subprocess, time

WAREHOUSE_ID = "6cd9ffe6ba1a7c82"  # Trial workspace "Serverless Starter Warehouse"
PROFILE = "actual-trial-personal-email"


def strip_line_comment(line):
    in_str = False
    i = 0
    while i < len(line) - 1:
        if line[i] == "'":
            in_str = not in_str
        elif not in_str and line[i:i + 2] == "--":
            return line[:i]
        i += 1
    return line


def split_statements(text):
    lines = [strip_line_comment(l) for l in text.split("\n")]
    text = "\n".join(lines)
    stmts, buf, in_str, i = [], [], False, 0
    while i < len(text):
        c = text[i]
        buf.append(c)
        if c == "'":
            in_str = not in_str
        elif c == ";" and not in_str:
            s = "".join(buf[:-1]).strip()
            if s:
                stmts.append(s)
            buf = []
        i += 1
    tail = "".join(buf).strip()
    if tail:
        stmts.append(tail)
    return stmts


def api(method, path, body=None):
    env = dict(os.environ, MSYS_NO_PATHCONV="1")
    cmd = ["databricks", "api", method, path, "-p", PROFILE]
    if body is not None:
        cmd += ["--json", json.dumps(body)]
    r = subprocess.run(cmd, capture_output=True, text=True, env=env)
    if r.returncode != 0:
        raise RuntimeError(f"CLI error: {r.stderr.strip()}")
    return json.loads(r.stdout)


def run_statement(sql, poll_interval=5, max_wait=1800):
    resp = api("post", "/api/2.0/sql/statements", {
        "warehouse_id": WAREHOUSE_ID,
        "statement": sql,
        "wait_timeout": "10s",
        "on_wait_timeout": "CONTINUE",
    })
    stmt_id = resp["statement_id"]
    waited = 0
    while resp["status"]["state"] in ("PENDING", "RUNNING"):
        if waited >= max_wait:
            raise TimeoutError(f"statement {stmt_id} still running after {max_wait}s")
        time.sleep(poll_interval)
        waited += poll_interval
        resp = api("get", f"/api/2.0/sql/statements/{stmt_id}")
    return resp


def main():
    arg = sys.argv[1]
    sql_text = open(arg, encoding="utf-8").read() if arg.endswith(".sql") else arg
    stmts = split_statements(sql_text)
    for s in stmts:
        t0 = time.perf_counter()
        preview = s[:80].replace("\n", " ")
        print(f"-- RUNNING: {preview}", flush=True)
        try:
            resp = run_statement(s)
            dt = time.perf_counter() - t0
            state = resp["status"]["state"]
            if state == "SUCCEEDED":
                result = resp.get("result", {})
                rows = result.get("data_array", [])
                cols = [c["name"] for c in resp.get("manifest", {}).get("schema", {}).get("columns", [])]
                print(f"-- OK ({dt:.1f}s): {preview}")
                if rows:
                    print("   ", cols)
                    for row in rows[:20]:
                        print("   ", row)
            else:
                err = resp["status"].get("error", {})
                print(f"-- FAILED ({dt:.1f}s, state={state}): {preview}")
                print("   ERROR:", err.get("message", resp["status"]))
        except Exception as e:
            dt = time.perf_counter() - t0
            print(f"-- EXCEPTION ({dt:.1f}s): {preview}")
            print("   ", e)


if __name__ == "__main__":
    main()
