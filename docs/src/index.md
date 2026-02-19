# HybridSystemsSimulations.jl

```@meta
CurrentModule = HybridSystemsSimulations
```

## Overview

`HybridSystemsSimulations.jl` is a power system operations simulation package that extends
[`PowerSimulations.jl`](https://nrel-sienna.github.io/PowerSimulations.jl/stable/) to model
hybrid systems (co-located renewable, thermal, and storage behind a single point of common
coupling). It provides device formulations, decision models, and constraints for
production-cost and merchant-style studies, including ancillary services and bilevel
formulations.

`HybridSystemsSimulations.jl` is an active project under development, and we welcome your
feedback, suggestions, and bug reports.

## About Sienna

`HybridSystemsSimulations.jl` is part of the National Laboratory of the Rockies's (NLR, formerly NREL)
[Sienna ecosystem](https://nrel-sienna.github.io/Sienna/), an open source framework for
power system modeling, simulation, and optimization. The Sienna ecosystem can be
[found on Github](https://github.com/NREL-Sienna/Sienna). It contains three applications:

  - [Sienna\Data](https://nrel-sienna.github.io/Sienna/pages/applications/sienna_data.html) enables
    efficient data input, analysis, and transformation
  - [Sienna\Ops](https://nrel-sienna.github.io/Sienna/pages/applications/sienna_ops.html)
    enables system scheduling simulations by formulating and solving optimization problems
  - [Sienna\Dyn](https://nrel-sienna.github.io/Sienna/pages/applications/sienna_dyn.html) enables
    system transient analysis including small signal stability and full system dynamic
    simulations

Each application uses multiple packages in the [`Julia`](http://www.julialang.org)
programming language.

## FlexPower Project

`HybridSystemsSimulations.jl` has been developed as part of the FlexPower Project at the
U.S. Department of Energy's National Laboratory of the Rockies
([NLR](https://www.nlr.gov/)), formerly NREL.

## Installation and Quick Links

  - [Sienna installation page](https://nrel-sienna.github.io/Sienna/SiennaDocs/docs/build/how-to/install/):
    Instructions to install `HybridSystemsSimulations.jl` and other Sienna\Ops packages
  - [`JuMP.jl` solver's page](https://jump.dev/JuMP.jl/stable/installation/#Install-a-solver): An appropriate optimization solver is required for running models. Refer to this page to select and install a solver for your application.
  - [Sienna Documentation Hub](https://nrel-sienna.github.io/Sienna/SiennaDocs/docs/build/index.html):
    Links to other Sienna packages' documentation

## How To Use This Documentation

This documentation is organized following the [Diataxis](https://diataxis.fr/) framework:

  - **Tutorials** - Detailed walk-throughs to help you *learn* how to use
    `HybridSystemsSimulations.jl`
  - **How to...** - Directions to help *guide* your work for a particular task
  - **Explanation** - Additional details and background information to help you *understand*
    `HybridSystemsSimulations.jl`, its structure, and how it works behind the scenes
  - **Reference** - API and technical reference for a quick *look-up* during your work
