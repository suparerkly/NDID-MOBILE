"""Build the Thai Playwright capture report (HTML) from a finished e2e-web run.

Usage (from the repo root, after ./tool/test_web.sh):
    python3 .claude/skills/ndid-testing/scripts/build_web_report.py OUT.html \
        [--results e2e-web/test-results/results.json] \
        [--artifacts e2e-web/test-results/artifacts] \
        [--meta 'Commit=abc123' --meta 'Chromium=147.0'] \
        [--finding 'หัวข้อ|รายละเอียด' ...] [--mutation 'M2|ชำระเงินได้โดยไม่ยอมรับเงื่อนไข|W3|CAUGHT' ...]

Reads results.json (Playwright JSON reporter) for status/duration of each test and the
captions.json that tests/helpers.mjs camera() writes next to each test's screenshots.
Screenshots are embedded as JPEG data URIs (412 px wide), so the page is one file.
Publish OUT.html with the Artifact tool. Every number on the page comes from the run.
"""
import argparse
import base64
import datetime
import html
import io
import json
import pathlib
import sys

from PIL import Image

HERE = pathlib.Path(__file__).resolve().parent
TEMPLATE = HERE.parent / "assets" / "web_report_template.html"


def jpeg(path: pathlib.Path) -> str:
    im = Image.open(path).convert("RGB")
    w = 412
    im = im.resize((w, round(im.height * w / im.width)), Image.LANCZOS)
    buf = io.BytesIO()
    im.save(buf, "JPEG", quality=78, optimize=True)
    return "data:image/jpeg;base64," + base64.b64encode(buf.getvalue()).decode()


def walk_specs(suite):
    for spec in suite.get("specs", []):
        yield spec
    for child in suite.get("suites", []):
        yield from walk_specs(child)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("out")
    ap.add_argument("--results", default="e2e-web/test-results/results.json")
    ap.add_argument("--artifacts", default="e2e-web/test-results/artifacts")
    ap.add_argument("--meta", action="append", default=[], help="Label=value shown in the header")
    ap.add_argument("--finding", action="append", default=[], help="title|detail")
    ap.add_argument("--mutation", action="append", default=[], help="id|bug|test|CAUGHT or MISSED")
    args = ap.parse_args()

    results = json.loads(pathlib.Path(args.results).read_text(encoding="utf-8"))
    captions = {}
    for f in pathlib.Path(args.artifacts).glob("*/captions.json"):
        data = json.loads(f.read_text(encoding="utf-8"))
        captions[data["title"]] = (f.parent, data["shots"])

    tests_html, nav, passed, total = [], [], 0, 0
    for suite in results["suites"]:
        for spec in walk_specs(suite):
            total += 1
            result = spec["tests"][0]["results"][-1]
            status = result["status"]
            ok = status == "passed"
            passed += ok
            code, _, title = spec["title"].partition(" ")
            anchor = f"t-{code.lower()}"
            nav.append(f'<a href="#{anchor}" class="navchip {"pass" if ok else "fail"}">{html.escape(code)}</a>')
            shots_html = []
            folder, shots = captions.get(spec["title"], (None, []))
            for i, shot in enumerate(shots, 1):
                img = folder / shot["file"]
                if not img.exists():
                    continue
                cap = html.escape(shot["caption"])
                shots_html.append(
                    f'<figure class="shot"><button class="zoom" type="button" aria-label="ขยายภาพ: {cap}">'
                    f'<img src="{jpeg(img)}" alt="{cap}" loading="lazy"></button>'
                    f'<figcaption><span class="n">{i:02d}</span>{cap}</figcaption></figure>'
                )
            errors = ""
            if not ok:
                msg = (result.get("error") or {}).get("message", "")
                errors = f'<pre class="err">{html.escape(msg[:1500])}</pre>'
            tests_html.append(
                f'<section class="test" id="{anchor}"><div class="test-head">'
                f'<span class="code">{html.escape(code)}</span><h3>{html.escape(title)}</h3>'
                f'<span class="pill {"pass" if ok else "fail"}">{"ผ่าน" if ok else "ไม่ผ่าน"}</span>'
                f'<span class="dur mono">{result["duration"] / 1000:.1f} s · {len(shots_html)} ภาพ</span></div>'
                f'{errors}<div class="shots">{"".join(shots_html) or "<p class=muted>ไม่มีภาพ</p>"}</div></section>'
            )

    stats = results["stats"]
    started = datetime.datetime.fromisoformat(stats["startTime"].replace("Z", "+00:00")).astimezone(
        datetime.timezone(datetime.timedelta(hours=7)))
    meta = [("วันที่", f"{started.day}/{started.month}/{started.year + 543} {started:%H:%M} น.")]
    meta += [tuple(m.split("=", 1)) for m in args.meta]
    meta_html = "".join(f"<span>{html.escape(k)} <b>{html.escape(v)}</b></span>" for k, v in meta)

    findings = "".join(
        f'<div class="card"><h3>{html.escape(t)}</h3><p>{html.escape(d)}</p></div>'
        for t, _, d in (f.partition("|") for f in args.finding)
    )
    mutations = "".join(
        f'<div class="mut-row"><span class="k mono">{html.escape(i)}</span><div><span>{html.escape(b)}</span>'
        f'<small>เทสต์ที่ควรจับ: {html.escape(t)}</small></div>'
        f'<span class="pill {"pass" if r == "CAUGHT" else "fail"}">{"จับได้" if r == "CAUGHT" else "จับไม่ได้"}</span></div>'
        for i, b, t, r in (m.split("|") for m in args.mutation)
    )

    all_ok = passed == total
    page = TEMPLATE.read_text(encoding="utf-8")
    for key, value in {
        "VERDICT_CLASS": "pass" if all_ok else "fail",
        "VERDICT": f"ผ่าน {passed} จาก {total} เทสต์" if all_ok else f"ไม่ผ่าน {total - passed} จาก {total} เทสต์",
        "PASSED": str(passed),
        "FAILED": str(stats.get("unexpected", total - passed)),
        "FLAKY": str(stats.get("flaky", 0)),
        "DURATION": f"{stats['duration'] / 1000:.0f}",
        "SHOTS": str(sum(len(s) for _, s in captions.values())),
        "META": meta_html,
        "NAV": "".join(nav),
        "TESTS": "".join(tests_html),
        "FINDINGS": findings,
        "FINDINGS_HIDDEN": "" if findings else "hidden",
        "MUTATIONS": mutations,
        "MUTATIONS_HIDDEN": "" if mutations else "hidden",
    }.items():
        page = page.replace("{{" + key + "}}", value)
    pathlib.Path(args.out).write_text(page, encoding="utf-8")
    print(f"wrote {args.out} ({len(page) // 1024} KB): {passed}/{total} passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
