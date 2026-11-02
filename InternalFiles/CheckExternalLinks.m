function report = CheckExternalLinks(options)
%CheckExternalLinks - Check external links in released courseware sources
%   REPORT = CheckExternalLinks() scans released courseware sources,
%   checks each unique HTTP(S) destination, and writes a Markdown report.
%
%   REPORT = CheckExternalLinks(Name=Value) also specifies options:
%       OutputFile      - Markdown report path
%       PerformRequests - Whether to send HTTP requests
%       Timeout         - Per-request timeout in seconds
%       SourceFiles     - Source files to scan
%
%   The checker follows redirects and reports their final destinations.
%
%   See also matlab.net.http.RequestMessage

arguments
    options.OutputFile (1,1) string = ""
    options.PerformRequests (1,1) logical = true
    options.Timeout (1,1) double {mustBePositive} = 15
    options.SourceFiles string = strings(0,1)
end

projectRoot = string(currentProject().RootFolder);
sourceFiles = options.SourceFiles;
if isempty(sourceFiles)
    sourceFiles = defaultSourceFiles(projectRoot);
end

outputFile = options.OutputFile;
if strlength(outputFile) == 0
    outputFile = fullfile(projectRoot, "InternalFiles", ...
        "ExternalLinkHealth.md");
end

references = extractReferences(sourceFiles, projectRoot);
details = summarizeReferences(references);
if options.PerformRequests
    details = checkDestinations(details, options.Timeout);
else
    details.Classification(:) = "Not checked";
    details.Message(:) = "Requests disabled";
end

summary = summarizeResults(details);
writeReport(outputFile, summary, details);

report = struct( ...
    "Summary", summary, ...
    "Details", details, ...
    "References", references, ...
    "OutputFile", outputFile);
end

function sourceFiles = defaultSourceFiles(projectRoot)
rootFiles = fullfile(projectRoot, ...
    ["README.md"; "README.m"; "MainMenu.m"; "StartingTips.m"]);
scriptFiles = listMFiles(fullfile(projectRoot, "Scripts"));
instructorFiles = listMFiles(fullfile(projectRoot, "InstructorResources"));
gettingStarted = fullfile(projectRoot, "InternalFiles", "GettingStarted.m");

sourceFiles = [rootFiles; scriptFiles; instructorFiles; gettingStarted];
sourceFiles = sourceFiles(isfile(sourceFiles));
sourceFiles = unique(sourceFiles, "stable");
end

function files = listMFiles(folder)
entries = dir(fullfile(folder, "**", "*.m"));
files = string(fullfile({entries.folder}, {entries.name}))';
end

function references = extractReferences(sourceFiles, projectRoot)
references = table( ...
    strings(0,1), strings(0,1), strings(0,1), zeros(0,1), ...
    VariableNames=["OriginalURL", "RequestURL", "Source", "Line"]);

for sourceFile = sourceFiles'
    content = fileread(sourceFile);
    if endsWith(sourceFile, ".m")
        appendixStart = strfind(content, "%[appendix]");
        if ~isempty(appendixStart)
            content = content(1:appendixStart(1)-1);
        end
    end

    [starts, ~, matches] = regexp(content, ...
        'https?://[^\s<>"'']+?(?=\]\(|[\s<>"'']|$)', ...
        "start", "end", "match");
    for index = 1:numel(matches)
        originalURL = cleanURL(matches{index});
        if strlength(originalURL) == 0
            continue
        end
        requestURL = regexprep(originalURL, "#.*$", "");
        lineNumber = 1 + sum(content(1:starts(index)-1) == newline);
        source = relativePath(sourceFile, projectRoot);
        references(end+1,:) = {originalURL, requestURL, source, lineNumber};
    end
end
end

function url = cleanURL(value)
url = string(value);
url = regexprep(url, '[.,;:!?]+$', "");
parenthesisDepth = 0;
for index = 1:strlength(url)
    character = extractBetween(url, index, index);
    if character == "("
        parenthesisDepth = parenthesisDepth + 1;
    elseif character == ")"
        if parenthesisDepth == 0
            url = extractBefore(url, index);
            break
        end
        parenthesisDepth = parenthesisDepth - 1;
    end
end
while endsWith(url, "]") && count(url, "]") > count(url, "[")
    url = extractBefore(url, strlength(url));
end
end

function path = relativePath(filePath, projectRoot)
filePath = string(filePath);
if startsWith(filePath, projectRoot + filesep)
    path = extractAfter(filePath, projectRoot + filesep);
else
    path = filePath;
end
path = replace(path, filesep, "/");
end

function details = summarizeReferences(references)
[requestURLs, ~, groupIndex] = unique(references.RequestURL, "stable");
count = numel(requestURLs);
details = table( ...
    requestURLs, strings(count,1), nan(count,1), strings(count,1), ...
    strings(count,1), zeros(count,1), strings(count,1), strings(count,1), ...
    VariableNames=["RequestURL", "Classification", "StatusCode", "Method", ...
    "FinalURL", "ReferenceCount", "Sources", "Message"]);

for index = 1:count
    matches = references(groupIndex == index,:);
    details.ReferenceCount(index) = height(matches);
    sources = matches.Source + ":" + string(matches.Line);
    details.Sources(index) = strjoin(unique(sources, "stable"), "<br>");
end
end

function details = checkDestinations(details, timeout)
for index = 1:height(details)
    [classification, statusCode, method, finalURL, message] = ...
        checkDestination(details.RequestURL(index), timeout);
    details.Classification(index) = classification;
    details.StatusCode(index) = statusCode;
    details.Method(index) = method;
    details.FinalURL(index) = finalURL;
    details.Message(index) = message;
end
end

function [classification, statusCode, method, finalURL, message] = ...
        checkDestination(url, timeout)
import matlab.net.http.HTTPOptions
import matlab.net.http.RequestMessage
import matlab.net.http.RequestMethod

httpOptions = HTTPOptions( ...
    ConnectTimeout=timeout, ...
    ResponseTimeout=timeout, ...
    DataTimeout=timeout, ...
    MaxRedirects=10, ...
    SavePayload=false);

try
    headRequest = RequestMessage(RequestMethod.HEAD, []);
    [response, ~, history] = headRequest.send(url, httpOptions);
    method = "HEAD";
    statusCode = double(response.StatusCode);
    if any(statusCode == [405 501])
        getRequest = RequestMessage(RequestMethod.GET, []);
        [response, ~, history] = getRequest.send(url, httpOptions);
        method = "GET";
        statusCode = double(response.StatusCode);
    end
    if isempty(history)
        finalURL = url;
    else
        finalURL = string(history(end).URI.EncodedURI);
    end
    historyStatusCodes = arrayfun( ...
        @(record) double(record.Response.StatusCode), history);
    redirected = any(historyStatusCodes >= 300 & historyStatusCodes < 400) || ...
        finalURL ~= url;
    classification = classifyResponse(statusCode, redirected);
    message = string(response.StatusLine.ReasonPhrase);
catch exception
    classification = "Failed";
    statusCode = NaN;
    method = "";
    finalURL = "";
    message = string(exception.message);
end
end

function classification = classifyResponse(statusCode, redirected)
if statusCode >= 200 && statusCode < 400
    if redirected
        classification = "Redirected";
    else
        classification = "Healthy";
    end
elseif any(statusCode == [401 403])
    classification = "Restricted";
else
    classification = "Failed";
end
end

function summary = summarizeResults(details)
categories = ["Healthy"; "Redirected"; "Restricted"; "Failed"; "Not checked"];
counts = zeros(numel(categories),1);
for index = 1:numel(categories)
    counts(index) = sum(details.Classification == categories(index));
end
summary = table(categories, counts, VariableNames=["Classification", "Count"]);
end

function writeReport(outputFile, summary, details)
outputFolder = fileparts(outputFile);
if ~isfolder(outputFolder)
    mkdir(outputFolder)
end

timestamp = string(datetime("now", Format="yyyy-MM-dd HH:mm:ss Z"));
lines = [
    "# External Link Health"
    ""
    "Generated: " + timestamp
    "Unique URLs checked: " + string(height(details))
    "Total references: " + string(sum(details.ReferenceCount))
    ""
    "## Summary"
    ""
    "| Classification | Count |"
    "| --- | ---: |"
    summary.Classification + " | " + string(summary.Count) + " |"
    ""
    "## Details"
    ""
    "| Classification | HTTP | Method | Original URL | Final URL | References | Sources | Message |"
    "| --- | ---: | --- | --- | --- | ---: | --- | --- |"
    detailRows(sortDetails(details))
    ];
writelines(lines, outputFile);
end

function details = sortDetails(details)
order = ["Failed"; "Restricted"; "Redirected"; "Healthy"; "Not checked"];
details.SortOrder = zeros(height(details),1);
for index = 1:numel(order)
    details.SortOrder(details.Classification == order(index)) = index;
end
details = sortrows(details, ["SortOrder" "RequestURL"]);
details.SortOrder = [];
end

function rows = detailRows(details)
rows = strings(height(details),1);
for index = 1:height(details)
    status = "";
    if ~isnan(details.StatusCode(index))
        status = string(details.StatusCode(index));
    end
    rows(index) = "| " + markdownText(details.Classification(index)) + ...
        " | " + status + ...
        " | " + markdownText(details.Method(index)) + ...
        " | " + markdownText(details.RequestURL(index)) + ...
        " | " + markdownText(details.FinalURL(index)) + ...
        " | " + string(details.ReferenceCount(index)) + ...
        " | " + markdownText(details.Sources(index)) + ...
        " | " + markdownText(details.Message(index)) + " |";
end
end

function value = markdownText(value)
value = replace(string(value), "|", "\|");
value = replace(value, newline, " ");
end
