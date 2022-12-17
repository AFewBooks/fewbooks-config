# Few Books Config


# Introduction

I love version control. It provides so much safety and flexibility. Unfortunately, version control (with Git) of documents isn't always intuitive. This is because many documents are saved in a binary format.

Adding the documents to Git works in the same way as for any other file - but Git can't provide useful diffs (the ability to compare between two versions of the same document) due to the files being binary. 

This repo includes some files to assist those creating documents with Microsoft Word and using it's binary format gain the benefit of clear diffing.

**Side Note**: If you don't need the formatting options provided by Word I highly recommend using markdown directly for composing (at least the original version of) the document and avoiding all this complexity. You can always uses pandoc later to convert the file from markdown to Microsoft Word (or any of a multitude of other formats).


# Instructions


## Do It Once Per Computer

1. Install [pandoc](http://pandoc.org/)


## Do It For Each New Document Repo

1. Create a new repo for your document(s).
2. Copy `.gitattributes`, `.gitconfig`, and `.gitignore-template` into your new repo.
3. Rename `.gitignore-template` to `.gitignore` and follow the instructions in the file to ensure the Windows document temporary file is not added to version control.
4. Copy the `.git-hooks` directory into the root of you repository. This directory contains the hooks `pre-commit` and `post-commit`.
5. Open the direct `repo-name/.git/hooks` in the terminal and create soft links to the files in `.git-hooks`:
    - ln -s ../../pre-commit pre-commit
    - ln -s ../../post-commit post-commit


### Alternative Method

Instead of doing steps 4 and 5 above you can copy the files `pre-commit` and `post-commit` directly into the `.git/hooks` directory.

- Why? Some people dislike having a `.git-hooks` directory in the root of their repo. Placing the files directly in `.git/hooks` avoids creating this `.git-hooks` directory.
- Why not? For people like myself who need visual cues to remind them to perform certain tasks having the `.git-hooks` folder in the root of the repo is a visual reminder to setup these scripts.


## Troubleshooting

- Make sure that the `pre-commit` and `post-commit` files are executable: 
    `chmod u+x pre-commit post-commit.sh`
- Make sure pandoc is installed on your computer.


# How It Works

When you make a commit Git runs any `pre-commit` hooks. Our `pre-commit` hook makes a Markdown format copy (`.md`) of any `.docx` files in the commit. It then lists the `.md` file names in a temorary file called `.commit-amend-markdown.`

After the commit is completed Git calls the `post-commit` hook. This hook checks for the temporary file `.commit-amend-markdown`. If the file exists, the hook amends the commit by adding the `.md` files to it. 


# Acknowledgments

The core of this software is the pre-commit and post-commit hooks which were created by Ramon Casero as part of Gerardus. See the [license file](license.md) for details.

I used several different articles to get `.gitattributes` and `.gitconfig` files that worked, unfortunately I do not have records of which articles. My sincere thanks to their authors.


# TODO

- Look at using lefthook to remove manual placement of files in `.git/hooks`.
- Look at using a batch script to handle moving the files and/or creating soft links.


# Other Notes
- The reason why we cannot simply add the `.md` files during the `pre-commit` script is because `git add` adds files to the next commit, not the current one.