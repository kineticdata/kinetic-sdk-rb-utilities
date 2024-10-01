# Kinetic Data SDK Courses
## Overview 
This repository contains files to be used alongside the Kinetic Data SDK Courses. The repository contains example scripts that are presented in the course and example scripts

The scripts leverage the Kinetic Ruby SDK as a gem. Docs can be found here https://rubygems.org/gems/kinetic_sdk

## Usage
This directory contains a directory for each of the courses.
- Course 1 (Introduction to the Kinetic Ruby SDK)
- Course 2 (Kinetic Data SDK Deep Dive)

Each of the course directories contains examples and supporting documentation for the course.

## Course 1
Examples from the presentation are included.

## Course 2
Each of the Exercises has a script example in the Exercises dirctory. There is a beginning and end state for each script example (excercise_XX_{begin OR end}.rb) The state of the script examples

### Setup
Course 2 has some setup requireed.

Add Form Attribute Definition - Add "Owning Team"
Import forms:
- general-facilities-request
- general-finance-request
- general-hr-request
- general-it-request
- general-legal-request
- general-marketing-request

## Requirements
- Ruby
- kinetic_sdk

## Optiional
- Git (used for downloading this repository to your local machine.)

## Setup
- Download this repository to your local machine. 
    - Download and extract zip file.
    - Clone the respositiory into a local directory
- Ruby is required on the machine running the scripts (https://www.ruby-lang.org/en/documentation/installation/)
    - Follow instructions related to your OS type
    - Verify installation by running `ruby -v` from the command line.
- Kinetic SDK (https://rubygems.org/gems/kinetic_sdk)
    - Run `gem install kinetic_sdk` from the command line