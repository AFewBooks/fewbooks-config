# Few Books Config

## Introduction
Keeping documents in version control isn't always the easiest task. If you write them in a plain text format (e.g. markdown) then everything is grand. But most document formats aren't plain text but binary (e.g. Microsoft Word). They can still be added to version control but one of the big advantages of Git is the ability to "diff" (see differences between two versions of the same document).

This repo includes some files to assist writers who are using Word and it's binary format in adding their files to version control with the benefit of "diffing."

## TODO
- Look at using lefthook to remove manual placement of files in `.git/hooks`.

## Instructions
### Do It Once Per Computer
1. Install pandoc
2. Install node.js

## Do It For Each New Document Repo
1. Create a new repo for your document(s).
2. Copy `.gitattributes`, `.gitconfig`, `.gitignore-template`, and .`package.json-template` into your new document repo.
3. Rename `.gitignore-template` to `.gitignore` and follow the instructions in the file to ensure the Windows document temporary file is not added to version control.
4. Rename `package.json-template` to `package.json`. Change the `name` value to reflect your document(s) and the "repository" "url" to point to your repository for the document(s).
5. Copy `post-commit` and `pre-commit` into the `.git/hooks` directory within your repo.

## Acknowledgments
The core of this software is the pre-commit and post-commit hooks which were created by Ramon Casero as part of Gerardus. See the [license file](license.md) for details.

I used several different articles to get `.gitattributes` and `.gitconfig` files that worked, unfortunately I do not have records of which articles. My sincere thanks to their authors.

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