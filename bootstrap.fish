# Bootstrap a project.

set _this_dir (dirname (readlink -m (status --current-filename)))
. $_this_dir/templates.fish

##### Functions
function choice
  string join \n $argv | shuf -n1
end

function titlize
  echo $argv[1] | sed 's/[^a-zA-Z0-9]/ /g' | tr -s ' ' | sed 's/.*/\L&/; s/[a-z]*/\u&/g'
end

##### Defaults
  set _adj incredible mindblowing amazing remarkable
  set _noun project venture experience
  set _template_repo templates

##### Main script

set -l options
set options $options (fish_opt -s t -l template-repo --required-val)
set options $options (fish_opt -s d -l description --required-val)
argparse --min-args 1 $options -- $argv
or exit 1

echo "Checking input and dependencies."
set _project "$argv[1]"
if test -z "$_project"
  echo "Usage: gh-bootstrap <repo-name>"
  exit 1
end
if test -e "$_project"
  echo "Project directory at $_project already exists. Not touching it."
  exit 1
end
if ! type -q gh
  echo "Github CLI (gh) not found."
  exit 1
end
if ! type -q vf
  echo "Virtualfish (vf) not found."
  exit 1
end
if ! gh auth status
  echo "Exiting due to Github auth failure above."
  exit 1
end
if ! type -q jq
  echo "jq not found."
  exit 1
end
if test -n _flag_description
  set _description $_flag_description
end

echo "Cloning or creating the repo."
set _repo (gh repo view $_project --json name -q '.["name"]')
if test -n "$_repo"
  echo "Bootstrapping $_project by cloning existing repo $_repo"
  if ! gh repo clone $_repo
    echo "Failed to clone repo"
    exit 1
  end
else
  set _default_description (titlize "the "(choice $_adj)" $_project "(choice $_noun))
  if test -z "$_description"
    read -P "Description ($_default_description): " _description
  end
  if test -z "$_description"
    set _description $_default_description
  end
  echo "Bootstrapping $_project ($_description) with a new repo."
  gh repo create --private --description "$_description" --clone --license "MIT" "$_project"
  set _repo (gh repo view $_project --json name -q '.["name"]')
end

echo "Getting repo details."
cd $_project
set _description (gh repo view --json description -q '.description')
git branch --remotes --list '*/HEAD' | tr -s ' ' | cut -d ' ' -f4 | tr '/' ' ' | read -t _remote _default_branch
echo "Local:           "(pwd) 
echo "Remote:          $_remote"
echo "Default branch:  $_default_branch"
echo "Description:     $_description"

echo "Checking default branch is ready."
if ! begin
    git checkout $_default_branch
    and git pull
  end
  echo "Couldn't checkout `$_default_branch` and pull. I'm confused."
  exit 1
end

echo "Creating virtualenv $_project"
vf new $_project; and vf connect


echo "Creating or updating template branch."
echo "Template repo: $_template_repo"
set _install pip
if ! type -q cruft
  set _install $_install cruft
end
if ! type -q jc
  set _install $_install jc
end
echo "Installing $_install..."
pip install --upgrade $_install
if ! git checkout -b template

  echo "Template branch exists."
  set _template_checkout jq '.checkout'
  echo "Template checkout branch: $_template_checkout"
  cruft update -c $_template_checkout
  echo "Template updated. Next steps: review, commit and merge to main, rebasing develop and feature branches."
  exit 0
end

echo "Branches initialized:"
git branch -a

echo "Template branch is new."
git push --set-upstream $_remote template
set _template (get_template_selection)
set _template_url (echo $_template | cut -f1)
set _template_branch (echo $_template | cut -f2)
set _context project=(titlize $_project)
set _context $_context repo_url=(gh repo view --json url -q '.["url"]')
set _context $_context "description=$_description"
echo "Context:"
echo $_context
set _context_json (string join \n $_context | jc -r --env)
echo "Context JSON:"
echo $_context_json
set _cruft cruft create $_template_url --checkout $_template_branch --extra-context $_context_json -f --output-dir . 
echo "Running cruft with: $_cruft"
cd ..
$_cruft

cd $_project
git add .  \
  && git commit -m "Initial template generation"  \
  && git push  \
  && git checkout $_default_branch  \
  && git merge --ff-only template  \
  && git push

if ! make check-version
  echo "Tagging initial release."
  make tag-release && git push --tags
end

# Set up develop branch
git checkout $_default_branch
if git checkout -b develop
  echo "Created develop branch."
  if ! make check-version
    echo "Bumping version on develop."
    set _commit_message (make bump-version | tail -n1)
    if string match --regex '^Bump version' $_commit_message
      git add .
      git commit -m "$_commit_message"
      poetry install
    else
      echo "Error bumping version. Output was: $_commit_message"
  end
end

  git push --set-upstream $_remote develop
else
  echo "Develop branch exists. Rebase on or merge from main."
end


