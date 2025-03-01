const core = require('@actions/core');
const github = require('@actions/github');
const fs = require('fs');
const { execSync } = require('child_process');

async function run() {
  try {
    const changelogFile = core.getInput('changelog_file') || 'CHANGELOG.md';
    const versionFile = core.getInput('version_file') || 'package.json';
    const sourceBranch = github.context.payload.pull_request?.head?.ref;
    const targetBranch = github.context.payload.pull_request?.base?.ref || 'main';

    const red = '\x1b[31;1m';
    const green = '\x1b[32;1m';
    const nc = '\x1b[0m'; // No Color

    function echoRed(message) {
      console.log(`${red}❌ ${message}${nc}`);
    }

    function echoGreen(message) {
      console.log(`${green}✅ ${message}${nc}`);
    }

    function readVersion(fileContent) {
      return JSON.parse(fileContent).version;
    }

    // Install dependencies
    execSync('npx -q semver-compare-cli --help > /dev/null || npm install -g semver-compare-cli');
    execSync('npx -q changelog-parser --help > /dev/null || npm install -g changelog-parser');

    // Make sure CHANGELOG has Unix line endings
    if (fs.existsSync(changelogFile)) {
      execSync(`sed -i.bak 's/\\r$//' ${changelogFile}`);
    } else {
      console.log('No changelog file detected');
    }

    // Gather version info
    execSync(`git fetch origin ${targetBranch}`);
    const targetRef = `origin/${targetBranch}`;
    console.log(`target ref ${targetRef}`);
    const commonAncestor = execSync(`git merge-base HEAD ${targetRef}`).toString().trim();
    const changedFiles = execSync(`git diff -w --name-only HEAD ${commonAncestor}`).toString().trim();
    const changedFilesToTarget = execSync(`git diff -w --name-only HEAD "${targetRef}"`).toString().trim();

    let currentVersion = '0.0.0';
    if (fs.existsSync(versionFile)) {
      currentVersion = readVersion(fs.readFileSync(versionFile, 'utf8'));
    } else {
      console.log('No package json exists, assuming v0.0.0');
    }

    let remoteVersion = '0.0.0';
    try {
      remoteVersion = readVersion(execSync(`git show ${targetRef}:${versionFile}`).toString());
    } catch (e) {
      console.log(`No remote ${versionFile} exists, assuming v0.0.0`);
    }

    let oldVersion = '0.0.0';
    try {
      oldVersion = readVersion(execSync(`git show ${commonAncestor}:${versionFile}`).toString());
    } catch (e) {
      console.log(`No old ${versionFile} exists, assuming v0.0.0`);
    }

    console.log(`REMOTE_VERSION=${remoteVersion}`);
    console.log(`OLD_VERSION=${oldVersion}`);
    console.log(`CURRENT_VERSION=${currentVersion}`);

    // Run all checks
    let failed = false;

    if (changedFiles.includes(versionFile)) {
      echoGreen(`${versionFile} file changed on ${sourceBranch}`);
    } else {
      echoRed(`${versionFile} file did not change on ${sourceBranch}`);
      failed = true;
    }

    if (changedFilesToTarget.includes(versionFile)) {
      echoGreen(`${versionFile} file changed compared to current ${targetBranch}`);
    } else {
      echoRed(`${versionFile} file did not change compared to current ${targetBranch}`);
      failed = true;
    }

    console.log(execSync(`npx semver-compare-cli ${currentVersion} gt ${oldVersion}`));
    if (execSync(`npx semver-compare-cli ${currentVersion} gt ${oldVersion}`).toString().trim() === '0') {
      echoGreen(`version in ${versionFile} increased on ${sourceBranch}`);
    } else {
      echoRed(`version in ${versionFile} needs to increase on ${sourceBranch}`);
      failed = true;
    }

    if (execSync(`npx semver-compare-cli ${currentVersion} gt ${remoteVersion}`).toString().trim() === '0') {
      echoGreen(`version in ${versionFile} increased compared to current ${targetRef}`);
    } else {
      echoRed(`version in ${versionFile} needs to be higher than on ${targetRef}`);
      failed = true;
    }

    let changelogStruct = '{"versions":[]}';
    if (fs.existsSync(changelogFile)) {
      changelogStruct = execSync(`npx changelog-parser ${changelogFile}`).toString();
    }

    try {
      JSON.parse(changelogStruct).versions.find(v => v.version === currentVersion);
      echoGreen(`${changelogFile} file contains ${currentVersion}`);
    } catch (e) {
      echoRed(`${changelogFile} file does not contain ${currentVersion}`);
      failed = true;
    }

    if (changedFiles.includes(changelogFile)) {
      echoGreen(`${changelogFile} file changed on ${sourceBranch}`);
    } else {
      echoRed(`${changelogFile} file did not change on ${sourceBranch}`);
      failed = true;
    }

    if (changedFilesToTarget.includes(changelogFile)) {
      echoGreen(`${changelogFile} file changed compared to current ${targetBranch}`);
    } else {
      echoRed(`${changelogFile} file did not change compared to current ${targetBranch}`);
      failed = true;
    }

    if (failed) {
      core.setFailed('Some checks for versioning failed');
    }
  } catch (error) {
    core.setFailed(error.message);
  }
}

run();