# Third-party notices

claude-shield includes work from the following projects.

## Lasso Security — claude-hooks (injection pattern library)

The 96 prompt-injection regex patterns at `claude/data/injection-patterns.json`
are derived from Lasso Security's open-source pattern library:

  https://github.com/lasso-security/claude-hooks

Lasso's original `patterns.yaml` is reproduced here in its entirety (with no
modifications to the patterns themselves), flattened into JSON at
`claude/data/injection-patterns.json` for runtime loading by
`claude/scripts/output-scanner.py`. The runtime scanner and surrounding hook
plumbing (from claude-shield) are original work.

Lasso's license is reproduced below per its terms.

---

MIT License

Copyright (c) 2026 Lasso

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
