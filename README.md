# CITest : A Modular Platform for Testing Cochlear Implant Perception

## OVERVIEW

CITest is a MATLAB-based program to control psychophysical hearing experiments for wearers of Advanced Bionics cochlear implants. It was developed, starting in 2011, for the Cochlear Implant Psychophysics Laboratory at the University of Washington in Seattle. The software was originally distributed to authorized external laboratories via a shared folder on Dropbox, where this GitHub repository will continue to be mirrored.

Please see the documentation file, [CITest_Documentation.pdf](./documentation/CITest%20Documentation_v01.21.pdf), for a complete overview of the CITest software suite and instructions for setting it up. Additional information about the primary program files (MATLAB functions, scripts, and figures) are listed below.

### System Requirements

The software, currently at __version 1.27__, has been tested with MATLAB R2017B running on the Windows 7 and Windows 10 operating systems. Earlier versions of CITest (contact S. Bierer for access) were designed to run on MATLAB R2007B and higher. No additional toolboxes are required.

The program requires installation of the Bionic Ear Data Collection System (BEDCS), version 1.18, available from the (Advanced Bionics Corporation)[https://advancedbionics.com/us/en/home.html]. To generate electrical stimulation through an implant, an Advanced Bionics research interface compatible with BEDCS is also required. Without this hardware connection, which enables an implant to be controlled by the host PC, only the "demo" mode of CITest will function.

### Features

CITest was designed to be __highly modular__, an improvement over conventional custom solutions where each new experiment often requires its own program.
- Different types of measurements can be made, such as threshold, maximum-comfort level, and pitch discrimination.
- Different perception paradigms can be applied, such as 2-alternative forced-choice or method of adjustment.
- The underlying code for a measurement or paradigm stays the same, providing reliability and portability.

The program is also __highly flexible__ in terms of how channels and current levels are specified.
- The measurement modules can be applied to one channel or several sequential channels, defined by the user via a special GUI.
- Monopolar, bipolar, tripolar, and quarupolar electrode configurations are supported.
- Parameterized sharpening (sigma) and steering (alpha) are also supported, allowing even more flexibility in defining channels.
- Current levels can be set with respect to subject threshold or comfort level (e.g. the program parses the user-supplied string "thr +2dB" to set a starting level to 2 dB log units above threshold).
- Pulse shapes are fully customizable within the contstraints of BEDCS (e.g. standard bipolar, pseudo-monopolar).

One of the modules offers a __fast measurement__ of thresholds or masking patterns by sweeping across the electrode array. See Bierer _et al_ (Trends in Hearing: 2015) for a description of this functionality, analagous to a procedure using acoustic stimuli put forth by Bekesy.

Analysis of data during and after acqusition is customizable by automatic invocation of __user-written analysis functions__.

As expected for any neuro-stimulatory system, numerous __failsafes__ are implemented to reduce the risk of over-stimulation.
- Impedances of all electrodes can be measured and saved to provide a hard upper-limit of safe current injection.
- Maximum comfort levels, specific to each configuration, must be specified before stimulation can occur.
- The controller is warned if currents for a particular configuration are atypically high.
- Safeguards set in CITest act on top of those implemented by BEDCS.

The software is __HIPAA compliant__.
- User identities and implant serial numbers are not stored or output by the software.

## FILE DESCRIPTIONS

File | Type | Description
---- | ---- | -----------
CITest.m | function | Main GUI program, the starting point to launch CITest
CITest.fig | figure | Main GUI figure (see Fig. 1 above), called by CITest.m
--- | --- | _To be filled in soon_
analyze_thrsweeps.m | script | [in "custom analysis"] Utility to process channel sweep data
custom_threshold.m | function | [in "custom analysis"] Extension for customizing data analysis; calls analyze_thrsweeps.m by default
loadresults_citest.m | function | [in "custom analysis"] Utility to collect related results files for further analysis

## USAGE INFORMATION

While CITest is freely distributed, please contact the principal investigator, Julie Arenberg, at julie_arenberg@meei.harvard.edu if you intend to use the software in any form. Access to BEDCS and the interface hardware must be arranged directly through Advanced Bionics (Sylmar, CA).

Be aware that most institutions require prior approval of an experimental protocol before any research with human participants can be conducted. The creators will not be liable for any damages caused by use of this code or modified versions of it. The application of safe stimulation practices are solely the responsibility of the end user. As such, it is recommended that all users carefully understand how the program controls current intensity and the implementation and limitations of the safeguards.

Data or analysis, published or presented, that was made using this software should reference the following journal article: Bierer JA, Bierer SM, Kreft HA, Oxenham AJ. A fast method for measuring psychophysical thresholds across the cochlear implant array. _Trends in Hearing_. vol 19. 2015. (https://www.ncbi.nlm.nih.gov/pubmed/25656797)
