# A systematic review of marine megafauna distribution and fisheries interaction in west Africa  - R Code

Also available for referencing in Zenodo  
[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.14847311.svg)](https://doi.org/10.5281/zenodo.14847311)


This repository provides the R code used in the following research paper:

Author
<a href="https://orcid.org/0000-0002-0072-1233">
  <img src="https://cdn.simpleicons.org/orcid/A6CE39" width="21"/>
</a>,
Author
<a href="https://orcid.org/0000-0002-0072-1233">
  <img src="https://cdn.simpleicons.org/orcid/A6CE39" width="21"/>
</a>,
... and Author
<a href="https://orcid.org/0000-0002-0072-1233">
  <img src="https://cdn.simpleicons.org/orcid/A6CE39" width="21"/>
</a>. 
Title...

------------------------------------------------------------------------

### Repository structure

| Folder | Description |
|----|----|
| *fun* | custom functions used into different scripts in `src` folder |
| *src* |  Source R scripts for data processing, statistical analysis, and visualization. |

### Abstract-screening adjudication

`src/05_summariseAbstractScreening.R` uses a separate workbook for manual
adjudication so reviewer decisions are never overwritten by generated output:

1. If `output/abstract_screening_reviewer3.xlsx` does not exist, the script
   creates it as a reviewer 3 template.
2. Complete the `reviewer_3` columns in its `final_screening` worksheet.
3. Rerun the script. Reviewer 3 values resolve disagreements and the adjudicated
   dataset is written to
   `output/abstract_screening/abstract_screening_final.xlsx`.

The reviewer 3 workbook is treated as a manual input and is not overwritten on
subsequent runs.

After adjudication, `src/06_prepareFullTextScreening.R` reads the generated
`abstract_screening_final.xlsx`, standardises the final categories, creates one
bar plot per screening variable, and exports:

- one workbook containing all accepted papers; and
- one workbook per standardised topic for full-text assignment.

These files are saved under `output/full_text_screening/`. Accepted papers with
no topic are retained in a separate `Unclassified` workbook.

### Data availability

See Data availability statement in the published article

### License

Copyright (c) 2026. David Ruiz-García, Leia Navarro-Herrero, Jazel Ouled-Cheikh, Paola Gabasa, Ignacio Saint-Malo, Alejandro Espada-Pastor, Diego Fernández-Fernández, David March (not in order of publication or anything atm)

@davidruizgarci
<a href="https://github.com/davidruizgarci">
  <img src="https://cdn.simpleicons.org/github/ffffff" width="22"/>
</a><a href="https://www.researchgate.net/profile/David-Ruiz-Garcia-3">
  <img src="https://cdn.simpleicons.org/researchgate/00CCBB" width="22"/>
</a>

@author ADD YOUR DETAILS
<a href="https://github.com/davidruizgarci">
  <img src="https://cdn.simpleicons.org/github/ffffff" width="22"/>
</a><a href="https://www.researchgate.net/profile/David-Ruiz-Garcia-3">
  <img src="https://cdn.simpleicons.org/researchgate/00CCBB" width="22"/>
</a>

Licensed under the [MIT License](https://github.com/SpatialMarine/REDUCE_review/blob/main/LICENSE)

### Acknowledgements

The study was supported by the EU Horizon REDUCE project...
