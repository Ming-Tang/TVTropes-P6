TVTropes-P6
===========

TVTropes page parser written in Perl 6.

This script breaks parsing down into multiple passes:

 - Pass 1: tokens and links
 - Pass 2: tags and basic structure
 - Pass 3: detailed document structure

This design reduces unneeded computation for those who only need the links but
does not care about the document's structure.

Download backup at 'https://archive.org/details/TvTropesArticleBackupjune2012'.

