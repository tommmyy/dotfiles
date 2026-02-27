---
name: how-to-write-skill
description: >
  Use this skill when the user wants to create a new SKILL.md for a technical or coding workflow.
  Trigger whenever the user says "write a skill", "create a skill", "make a skill file", "document this workflow",
  or asks how to teach Claude to do a repeatable technical task. Also trigger when a user has just
  completed a multi-step coding task and wants to capture it as a reusable skill.
---

# How to Write a SKILL.md (Technical / Coding Edition)

This skill guides you through writing a high-quality `SKILL.md` for technical and coding use cases —
the kind where Claude needs to run shell commands, generate files, use libraries, or follow a precise
multi-step workflow to produce a correct output.

---

## Mental Model: What a Skill Actually Is

A SKILL.md is **not documentation for humans**. It's a program for an LLM.

The LLM reads it once before acting. It then pattern-matches your instructions against what it already
knows about coding, tools, and file systems. Your job is to reduce ambiguity, prevent known failure modes,
and provide concrete anchors (real code, real commands) that the LLM can reliably adapt.

Think of it like writing a `package.json` + `Makefile` with inline comments — terse, precise, executable in sequence.

---

## File Structure

```
my-skill/
├── SKILL.md                  ← Required. The LLM reads this first.
└── resources/
    ├── template.py           ← Boilerplate the LLM copies and adapts
    ├── example_output.xlsx   ← Reference output for quality bar
    └── reference.md          ← Long docs, API refs, gotchas (loaded on demand)
```

Keep `SKILL.md` under ~500 lines. Offload anything longer to `resources/` and reference it explicitly.

---

## SKILL.md Template

```markdown
---
name: <kebab-case-name>
description: >
  [What this skill does + when to trigger it. Be specific about trigger phrases.
   Include the domain: "Use when the user asks to generate X / convert Y / run Z"]
---

# <Skill Title>

## Purpose

[One paragraph. What problem does this solve? What does success look like?]

## Dependencies

\`\`\`bash
npm install <package>

# for global CLI tools:

npm install -g <package>
\`\`\`

Verify availability before use:
\`\`\`bash
node -e "require('<package>'); console.log('ok')"
\`\`\`

## Inputs

- `<var>`: [type, description, example]
- `<var>`: [type, description, example]

## Steps

### 1. [Step Name]

[One sentence: what this step does and why]

\`\`\`python

# Minimal working code for this step

\`\`\`

### 2. [Step Name]

...

## Output

- File path: `/mnt/user-data/outputs/<filename>.<ext>`
- Format: [describe structure, encoding, key fields]
- Always call `present_files(["<path>"])` at the end.

## Common Mistakes

- ❌ Don't do X because Y → ✅ Do Z instead
- ❌ Don't do X because Y → ✅ Do Z instead

## Complete Working Example

[Full end-to-end snippet the LLM can copy-paste and adapt. No placeholders.]

## Notes / Edge Cases

[Optional. Only include if genuinely non-obvious.]
```

---

## Section-by-Section Guide

### `description` (frontmatter)

This is the **trigger**. Claude decides whether to load the skill based solely on this field.

Rules:

- Include both **what** it does and **when** to use it
- List specific user phrases that should trigger it
- Be slightly "pushy" — LLMs undertrigger, so lean toward broader coverage

```yaml
# Weak ❌
description: Creates Excel files.

# Strong ✅
description: >
  Use this skill to generate .xlsx spreadsheet files using Node.js + exceljs.
  Trigger whenever the user asks to "create a spreadsheet", "export to Excel",
  "make a table", or requests any .xlsx/.csv output. Also trigger when the user
  uploads data and wants it formatted as a downloadable file.
```

---

### Dependencies

Always include the exact install command. Never assume packages are available.

```bash
pip install openpyxl --break-system-packages   # ← always include the flag
pip install pandas --break-system-packages
```

If the skill uses a CLI tool, check it exists:

```bash
which ffmpeg || apt-get install -y ffmpeg
```

---

### Steps

Use numbered `###` headers. Each step should be:

1. **Named** — not "Step 1" but "Parse Input CSV"
2. **One responsibility** — if a step does two things, split it
3. **Accompanied by working code** — not pseudocode

```markdown
### 3. Apply Header Formatting

Bold the first row and freeze the pane so headers stay visible when scrolling.

\`\`\`js
const ExcelJS = require('exceljs');
const worksheet = workbook.getWorksheet('Sales Report');

worksheet.getRow(1).eachCell(cell => {
cell.font = { bold: true };
cell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FF4472C4' } };
});

worksheet.views = [{ state: 'frozen', ySplit: 1 }];
\`\`\`
```

---

### Output Contract

Be explicit. The LLM needs to know exactly where to save things and how to hand them off.

```markdown
## Output

- Save to: `/mnt/user-data/outputs/report.xlsx`
- Always call `present_files(["/mnt/user-data/outputs/report.xlsx"])` after saving
- If the filename should reflect user input, derive it: `f"{topic.lower().replace(' ', '_')}.xlsx"`
```

---

### Common Mistakes

This section has outsized impact. LLMs repeat mistakes they've made in training. Preempt them.

Format as: ❌ Mistake → why it fails → ✅ correct approach

```markdown
## Common Mistakes

- ❌ Using `require` on a package before `npm install` → module not found → ✅ always install first and verify with `node -e "require('pkg')"`
- ❌ Forgetting `async/await` on `workbook.xlsx.writeFile()` → file written as 0 bytes → ✅ always `await` file I/O
- ❌ Writing to `/home/claude/` and forgetting to copy → user can't download it → ✅ write directly to `/mnt/user-data/outputs/`
- ❌ Hardcoding worksheet name as `'Sheet1'` → breaks when user names their sheet → ✅ derive from input or use a variable
- ❌ Not wrapping top-level async code in an IIFE or async function → `await` outside async context throws → ✅ wrap in `async function main() { ... } main()`
```

---

### Complete Working Example

The single highest-leverage section. A complete, runnable, no-placeholders example the LLM
can adapt without inventing anything from scratch.

Rules:

- Must run as-is (or with minimal substitution)
- Include imports
- Include file save + `present_files` call
- Use realistic sample data, not `"foo"` / `"bar"`

```js
const ExcelJS = require("exceljs");
const path = require("path");

async function generateReport() {
  const workbook = new ExcelJS.Workbook();
  const ws = workbook.addWorksheet("Sales Report");

  // Define columns (sets header + width)
  ws.columns = [
    { header: "Month", key: "month", width: 14 },
    { header: "Revenue", key: "revenue", width: 14 },
    { header: "Units Sold", key: "units", width: 14 },
    { header: "Avg Price", key: "avgPrice", width: 14 },
  ];

  // Style header row
  ws.getRow(1).eachCell((cell) => {
    cell.font = { bold: true, color: { argb: "FFFFFFFF" } };
    cell.fill = {
      type: "pattern",
      pattern: "solid",
      fgColor: { argb: "FF4472C4" },
    };
  });

  // Add data rows
  const data = [
    { month: "January", revenue: 42000, units: 210, avgPrice: 200 },
    { month: "February", revenue: 38500, units: 193, avgPrice: 199.5 },
    { month: "March", revenue: 51200, units: 256, avgPrice: 200 },
  ];
  data.forEach((row) => ws.addRow(row));

  // Freeze header row
  ws.views = [{ state: "frozen", ySplit: 1 }];

  const outputPath = "/mnt/user-data/outputs/sales_report.xlsx";
  await workbook.xlsx.writeFile(outputPath);
  console.log("Saved to", outputPath);
  // present_files([outputPath])  ← call this at the end of your task
}

generateReport().catch(console.error);
```

---

## Quality Checklist

Before finalizing your SKILL.md, verify:

- [ ] `description` includes trigger phrases a real user would say
- [ ] Every dependency has an exact install command
- [ ] Steps are sequential and each has working code
- [ ] Output path is `/mnt/user-data/outputs/` (not `/home/claude/`)
- [ ] `present_files` is called at the end
- [ ] "Common Mistakes" covers at least 3 real failure modes
- [ ] Complete example is copy-pasteable with no placeholders
- [ ] SKILL.md is under ~500 lines (offload the rest to `resources/`)

---

## When to Use Bundled Resources

| Situation                      | What to do                                              |
| ------------------------------ | ------------------------------------------------------- |
| Boilerplate > 50 lines         | Put in `resources/template.py`, reference from SKILL.md |
| Large API reference            | Put in `resources/reference.md` with a TOC              |
| Multiple variants (AWS vs GCP) | Separate files: `resources/aws.md`, `resources/gcp.md`  |
| Example output file            | Store in `resources/example_output.xlsx`                |

Reference from SKILL.md like:

```markdown
> Read `resources/reference.md` §3 for full API parameter list before writing the request.
```

---

## Anti-Patterns to Avoid

**Don't write prose instructions where code works better.**

```markdown
# ❌ Weak

Install the required packages before proceeding.

# ✅ Strong

\`\`\`bash
npm install exceljs
\`\`\`
```

**Don't use abstract placeholders in your example.**

```python
# ❌ Weak
data = [YOUR_DATA_HERE]

# ✅ Strong
data = [["Alice", 42, "Engineering"], ["Bob", 35, "Design"]]
```

**Don't describe the output — specify it.**

```markdown
# ❌ Weak

Save the file somewhere accessible.

# ✅ Strong

Save to `/mnt/user-data/outputs/<descriptive_name>.xlsx` and call `present_files`.
```

**Don't skip the verification step for tools/packages.**

```bash
# ✅ Always verify before using
node -e "require('exceljs')" || npm install exceljs
```
