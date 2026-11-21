# AI Agents Guidelines

> [!IMPORTANT]
> **ГЛАВНОЕ И ОБЯЗАТЕЛЬНОЕ ПРАВИЛО #1:**
> ПОСЛЕ ЛЮБЫХ ИЗМЕНЕНИЙ В ПРОЕКТЕ ВСЕ ИЗМЕНЕНИЯ ОБЯЗАТЕЛЬНО КОММИТАТЬ НА GITHUB И СРАЗУ ПУШИТЬ (`git add .`, `git commit -m "..."`, `git push origin master`), ЧТОБЫ У ДРУГА ВСЕГДА БЫЛА АКТУАЛЬНАЯ ВЕРСИЯ.
>
> **ГЛАВНОЕ И ОБЯЗАТЕЛЬНОЕ ПРАВИЛО #2:**
> **НИКОГДА НЕ УДАЛЯТЬ ИЗМЕНЕНИЯ, ОБЪЕКТЫ, СКРИПТЫ ИЛИ ИНТЕРФЕЙСЫ, КОТОРЫЕ ДОБАВЛЯЕТ ДРУГ В ПРОЕКТ.** Если друг что-то добавил в Team Create / Workspace / StarterGui / и т.д. — оставлять это нетронутым, если пользователь прямо не попросил удалить конкретно это.

---

## Instructions for AI Assistants / Agents

1. **Auto-commit & Push**:
   - Any time you make changes to scripts, configurations, models, or documentation in this repository, you **MUST** immediately stage, commit with a descriptive message, and push the changes to GitHub (`origin master`).
   - Do not leave uncommitted or unpushed changes.
2. **Rojo & Roblox Studio Sync**:
   - Keep `default.project.json` and files under `src/` synchronized with the live Roblox Studio place.
   - Maintain clean, modular code.
