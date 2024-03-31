#!/bin/bash

set -xeuf -o pipefail

for nimVersion in 2.0.0 1.6.14; do
    for threads in on off; do
        for target in benchmark test; do
            act -W .github/workflows/build.yml -j "$target" --matrix "nim:$nimVersion" --matrix "threads:$threads";
        done
    done

    for project in NecsusECS/NecsusAsteroids NecsusECS/NecsusParticleDemo; do
        act -W .github/workflows/build.yml -j example-projects --matrix "nim:$nimVersion" --matrix "project:$project";
    done

    for target in readme profile float32; do
        act -W .github/workflows/build.yml -j "$target" --matrix "nim:$nimVersion";
    done
done