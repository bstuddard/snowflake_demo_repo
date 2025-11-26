LS @git_clone_repo/branches/main/;

ALTER GIT REPOSITORY git_clone_repo FETCH;

LS @git_clone_repo/branches/main/;

EXECUTE IMMEDIATE FROM @git_clone_repo/branches/main/admin_scripts/test_repos.sql