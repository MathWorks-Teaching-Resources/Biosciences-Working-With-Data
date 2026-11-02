# Instructor Resources

This folder contains material for educators adapting and delivering this
courseware module. It is intentionally not placed on the MATLAB project path,
so helper files and solutions do not become student-facing dependencies.

Open the instructor documentation viewer with the **Instructor resources** button in the startup app, or run `InstructorResources`. The [instructor documentation](Documentation/README.md) describes the current toolkit and student-copy workflow.

## Start Here

- [Customize Live Scripts](Documentation/CustomizeLiveScripts.md) explains how to tailor a
  supplied activity while retaining a reproducible original.
- [Using Git](Documentation/UsingGit.md) and [Using GitHub](Documentation/UsingGitHub.md) introduce the
  version-control and publishing workflows.
- `Solutions/` holds instructor solution scripts corresponding to learner
  activities in `Scripts/`.

## Create a Student-Only Copy

Run `CreateStudentVersion` from this folder while the faculty project is open:

```matlab
run(fullfile(currentProject().RootFolder, ...
    "InstructorResources", "CreateStudentVersion.m"))
```

Choose one of the following modes:

1. **Sibling export** creates a separate `<module>-Student` folder beside the
   faculty project.
2. **Student branch** creates a separate Git working tree on a new local
   `student` branch. The command stops if that branch already exists.

Both modes retain the learner-facing project, activities, required runtime
files, `LICENSE.md`, and `SECURITY.md`. They remove instructor resources,
internal authoring material, tests, CI, build tooling, and contribution
guidance. The generated project sets `HideInstructorResources = true` in its startup
app; feedback actions open the student feedback form.

The source project is not modified. Test the generated copy before
distribution.

## Host Your Copy

After creating and reviewing a student copy, follow
[Using GitHub](Documentation/UsingGitHub.md) to create and publish an instructor-controlled
repository.
