# SUMMARY

"pre-commit-git-diff-docx.sh:" Small git (https://git-scm.com/) hook. It works in combination with another hook, "post-commit-git-diff-docx.sh".

Together, they keep a Markdown (.md) copy of .docx files so that git diffs of the .md files show the changes in the document (as .docx files are binaries, they produce no diffs that can be checked in emails or in the repository's commit page).

# DEPENDENCIES
- pandoc (http://pandoc.org/)

# INSTALLATION

1) put both scripts in the hooks directory of each of your git projects that use .docx files. There are several options, e.g. you can put them in ~/Software and soft link to them from the hooks directory, e.g.
    
    cd $PROJECTPATH/.git/hooks
    ln -s ~/Software/pre-commit-git-diff-docx.sh pre-commit
    ln -s ~/Software/post-commit-git-diff-docx.sh post-commit

    Or you can make a copy in the hooks directory

    cd $PROJECTPATH/.git/hooks
    cp ~/Software/pre-commit-git-diff-docx.sh pre-commit
    cp ~/Software/post-commit-git-diff-docx.sh post-commit

2) make sure that the scripts are executable
    cd ~/Software
    chmod u+x pre-commit-git-diff-docx.sh post-commit-git-diff-docx.sh

# DETAILS
This script makes a Markdown format copy (.md) of any .docx files in the commit. It then lists the .md file names in a temp file called .commit-amend-markdown.

After the commit, the post-commit hook "post-commit-git-diff-docx.sh" will check for this file. If it exists, it will amend the commit adding the names of the .md files.

The reason why we cannot simply add the .md files here is because `git add` adds files to the next commit, not the current one.

This script requires pandoc (http://pandoc.org/) to have been installed in the system.