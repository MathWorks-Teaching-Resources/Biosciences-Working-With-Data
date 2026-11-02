%[text] # Create a learner-only project distribution
%[text] This interactive guide creates a sibling copy of the open faculty project or a separate Git working tree on a new student branch in a new folder. The source checkout is never modified.
addpath(fullfile(currentProject().RootFolder,"InstructorResources","HelperFunctions"))
mode = "branch"; %[control:dropdown:7cc3]{"position":[8,16]}
%[text] Select `export` to create a sibling folder that is not a Git repository. Select `branch` to create a separate working tree. By default, the branch name is `student`.
%[text]
%[text] Optionally choose a name for the destination folder; otherwise, the new location is `<courseware-name>-Student`.
destinationFolder = ""; %[control:filebrowser:91f3]{"position":[21,23]}
branchName = "student"; %[control:editfield:1372]{"position":[14,23]}
%[text] The learner-only version retains runtime courseware files, `LICENSE.md`, and `SECURITY.md`, but removes instructor and authoring materials.
  %[control:button:2b7d]{"position":[1,2]}
outputFolder = CreateStudentVersionHelper(mode,Destination=destinationFolder,BranchName=branchName);
%%
  %[control:button:3c82]{"position":[1,2]}
if ~exist("outputFolder","var")
    outputFolder = currentProject().RootFolder+"-Student";
end
try
    cd(outputFolder)
catch ME
    disp(outputFolder + " doesn't exist. Please run this entire script.")
end
try
    close(currentProject())
catch ME
    % No project was loaded already
end
openProject(pwd);
%[text] The created project is ready to test and publish. See [Using GitHub](file:Documentation/UsingGitHub.md) for hosting instructions.

%%
%[text] ## Help us Improve
%[text] [Share your feedback](<matlab: ShareFeedback>) to help us improve this module.

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline","rightPanelPercent":40}
%---
%[control:dropdown:7cc3]
%   data: {"defaultValue":"\"export\"","itemLabels":["export","branch"],"items":["\"export\"","\"branch\""],"label":"mode","run":"Nothing"}
%---
%[control:filebrowser:91f3]
%   data: {"browserType":"File","defaultValue":"\"\"","label":"Select a folder location: ","run":"Nothing"}
%---
%[control:editfield:1372]
%   data: {"defaultValue":"\"student\"","label":"","run":"Nothing","valueType":"String"}
%---
%[control:button:2b7d]
%   data: {"label":"Create Student Version","run":"Section"}
%---
%[control:button:3c82]
%   data: {"label":"Open Student Version","run":"Section"}
%---
