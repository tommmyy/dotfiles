---
name: skill-improver
description: Improve skill from current context
disable-model-invocation: true
---

# Skill Improver

Use this after using a skill to improve the skill itself based on conversation context.

## Instructions

1. **Analyze Conversation Context**: Review the entire conversation to identify:
   - Which skill was used
   - What problems or struggles occurred (errors, misunderstandings, missing functionality)
   - What guidance the user provided to fix issues
   - What worked well and what didn't

2. **Identify the Skill File**:
   - Look for the skill name in the conversation
   - Find the corresponding SKILL.md file

3. **Determine Improvements**: Based on the struggles identified:
   - Add missing instructions or clarifications
   - Include specific commands or patterns that worked
   - Add context about common pitfalls to avoid
   - Update examples if needed
   - Add error handling guidance
   - **Save utility scripts**: If one-off scripts were generated during the workflow, and they are generic enough to use again, save them to the skill directory

4. **Update the Skill File**:
   - Read the current skill file
   - Make targeted improvements to address the identified issues
   - Preserve existing working instructions
   - Add new sections if needed (e.g., "Common Issues", "Important Notes")
   - Keep the skill focused and actionable

5. **Save Utility Scripts** (if applicable):
   - Look for one-off scripts generated during the conversation (bash, python, etc.)
   - Save them in the skill directory with descriptive names
   - Update the skill file to reference these scripts
   - Add usage instructions for the scripts

6. **Confirm Changes**: Briefly explain what improvements were made and why.

## What to Look For

- **User corrections**: "Actually, you need to...", "No, try...", "Use X instead of Y"
- **Repeated attempts**: Multiple tries to accomplish the same task
- **Error patterns**: Similar errors occurring multiple times
- **Missing context**: Information that should have been in the skill instructions
- **Ambiguities**: Parts where the skill could be interpreted in multiple ways
- **Generated scripts**: One-off utility scripts created during the workflow that could be reused

## Example Workflow

User runs a skill → Skill struggles → User guides it → User runs /skill-improver → Skill file is updated → Next time it works better
