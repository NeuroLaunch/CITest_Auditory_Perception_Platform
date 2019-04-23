# CITest : A Modular Platform for Testing Cochlear Implant Perception

## Overview

CITest is a MATLAB-based program to control psychophysical hearing experiments for wearers of Advanced Bionics cochlear implants. It was developed, starting in 2011, for the Cochlear Implant Psychophysics Laboratory at the University of Washington in Seattle. The software was originally distributed to authorized external laboratories via a shared folder on Dropbox, where this GitHub repository will continue to be mirrored.

Please see the documentation file, [CITest_Documentation.pdf](./documentation/CITest%20Documentation_v01.21.pdf), for a complete overview of the CITest software suite and instructions for setting it up. Additional information about the primary program files (MATLABL functions, scripts, and figures) are listed below.

### System Requirements

The software has been tested with MATLAB R2017B, running on the Windows 7 or Windows 10 operating systems. Earlier versions of CITest (contact S. Bierer for access) were designed to run on MATLAB R2007B and higher. No additional toolboxes are required.

The program requires installation of the Bionic Ear Data Collection System (BEDCS), version 1.18, available from the Advanced Bionics Corporation. To generate electrical stimulation through an implant, an Advanced Bionics research interface compatible with BEDCS is also required. Without this hardware connection, which allows an implant to be controlled by the PC hosting CITest, only the "demo" mode of CITest can be run.

### Features

## File Descriptions

File | Type | Description
---- | ---- | -----------
.m | function | Main GUI program, starting point to launch CITest

## Permissions

While CITest is freely distributed, please contact the principal investigator, Julie Arenberg, at julie_arenberg@meei.harvard.edu if you intend to use the software in any form. Access to BEDCS and a cochlear implant research interface must be arranged directly through Advanced Bionics (Sylmar, CA).

Data or analysis, published or presented, that was made using this software should reference the following journal article: Bierer JA, Bierer SM, Kreft HA, Oxenham AJ. A fast method for measuring psychophysical thresholds across the cochlear implant array. _Trends in Hearing_. vol 19. 2015. (https://www.ncbi.nlm.nih.gov/pubmed/25656797)
