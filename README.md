# AutoSort

AutoSort is a macOS menu bar app that keeps course materials organized for you. Drop files into a watch folder (or drag them into the menu bar) and AutoSort moves them into the right course and session folders based on the filename. It is designed for students and educators who regularly download lecture materials and want a clean, predictable folder structure without manual sorting.

**Highlights**
- Automatic sorting from a watch folder
- Manual drag-and-drop from the menu bar
- Course mapping auto-detection
- Custom session keywords and folder naming
- Duplicate handling (rename, skip, replace, or ask)

## What It Solves
If your Downloads folder keeps filling up with files like `CS101_S2_Slides.pdf` or `ML_Week4_Notes.docx`, AutoSort can move them into a structured library automatically:

```
Courses/
  CS101/
    Session 2/
      CS101_S2_Slides.pdf
  ML/
    Session 4/
      ML_Week4_Notes.docx
```

You decide the course codes and destination folder names. AutoSort detects the session number in the filename and builds the session folder for you.

## Core Workflow
1. **Choose a Watch Folder** (e.g., Downloads).
2. **Choose a Destination Folder** where course folders live.
3. **Create Course Mappings** (e.g., `CS101` → `Intro to CS`).
4. Drop files in the watch folder and AutoSort does the rest.

You can also drag files directly into the menu bar drop zone for one-off sorting without using the watch folder.

## Features & Functionality

### 1) Automatic Sorting
AutoSort monitors your chosen watch folder and moves files as soon as they appear. This is ideal for keeping Downloads clean while you focus on your work.

### 2) Manual Drag-and-Drop
Prefer to sort files on demand? Open the menu bar and drop one or more files into the drop zone. AutoSort will sort them immediately.

### 3) Course Mappings
Map a **course code** to a **destination folder name**:
- Example: `ML` → `Machine Learning`
- Example: `CS101` → `Intro to CS`

Only enabled mappings are used during sorting.

### 4) Auto-Detect Course Mappings
If you already have a partially organized course folder, AutoSort can scan it and suggest mappings. You can review and apply suggestions to save time.

### 5) Session Detection
AutoSort looks for a session keyword and number in the filename. You can customize the keywords, for example:
- `S` (e.g., `S3`)
- `Session` (e.g., `Session 12`)
- `Week` (e.g., `Week 4`)
- `Lecture` (e.g., `Lecture2`)

You can also choose how the session folder is named (for example: `Session {n}` or `Week {n}`).

### 6) Duplicate Handling
If a file with the same name already exists in the destination, you can choose what AutoSort should do:
- **Rename** (keep both files)
- **Skip** (leave the new file where it is)
- **Replace** (overwrite the old file)
- **Ask** (prompt each time)
