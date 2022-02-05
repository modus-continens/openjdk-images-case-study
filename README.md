# Modus' OpenJDK Images 📦

## Motivation & Background

Modus provides an alternative syntax to express Dockerfiles, and an alternative interface to BuildKit. Together, this provides a build system that makes it easier to define complex, parameterized builds with zero loss in efficiency w.r.t. time to build or image sizes. Furthermore, in a number of use cases, Modus makes image-creation workflows **more** efficient.

This repository hosts Modusfile(s) intended to generate OCI-compatible images that provide OpenJDK application runtimes. 

The [Docker Official Images](https://github.com/docker-library/official-images) project provides and maintains application runtimes packaged in images. Their image creation workflow involves [templated Dockerfiles](https://github.com/docker-library/openjdk/blob/c6190d5cbbefd5233c190561fda803f742ae8241/Dockerfile-linux.template), [bash scripts](https://github.com/docker-library/openjdk/blob/abebf9325fea4606b9759fb3b9257ea3eef40061/apply-templates.sh), as well as non-trivial [jq and awk processing](https://github.com/docker-library/bashbrew/blob/master/scripts/jq-template.awk).
Often, this serves as a method to conditionally execute some instruction, or select between some strings. Modus provides a cohesive system that replaces the need for Dockerfile templating, and most of the surrounding ad-hoc scripts.

[Here](#openjdk-configuration) is a summary of how we have parameterized OpenJDK builds. This demonstrates another advantage of Modus; using it requires you to think *explicitly* about the ways in which your builds can vary. In contrast, the official images *implicitly* define this through their [JSON versions file](https://github.com/docker-library/openjdk/blob/master/versions.json): it is not sufficient on its own to understand which configurations are valid. One also needs to check the other scripts or template files. For example, one would need to read their [templating script](https://github.com/docker-library/openjdk/blob/master/apply-templates.sh) to realize that Windows variants are handled differently[^alt].

[^alt]: This could also be solved by changing the format of their `versions.json` file. Nevertheless, it demonstrates a problem that emerges from complicated image creation systems.

### Baseline - Official Linux-based OpenJDK Dockerfiles

To provide a baseline for our performance tests, we built the [official Dockerfiles](https://github.com/docker-library/openjdk) sequentially using a shell script `time fdfind Dockerfile$ | rg -v windows | xargs -I % sh -c 'docker build . -f %'`.
![image](https://user-images.githubusercontent.com/46009390/152654516-7e6583ca-c52e-42f0-bad9-c89db768b2be.png)

As shown above, it took 16 minutes and 46 seconds to build 42 images with an empty build cache. This was performed with BuildKit activated.

## Summary of Results

- The baseline - building images sequentially from the official Dockerfiles - took 16:46.12 to build 42 images.
- Our approach - using Modus - took 13:34.48 to build the same 42 images.

The performance improvements from using Modus is due to the parallel build performed by our front-end to BuildKit (which can be viewed as the back-end to Modus) which takes the build plan, generated by the Modus front-end, and calls BuildKit using its awareness of the multiple images requested by the user.

## Building & Reproducing Results

`modus build . 'openjdk(A, B, C)' -f <(cat *.Modusfile)` should build all available images.

### System Specification for Results

All builds & experiments described in this document were performed on a machine with:
- Memory: 8GiB System memory
- Processor: [Intel(R) Core(TM) i5-10400F CPU @ 2.90GHz](https://www.intel.co.uk/content/www/uk/en/products/sku/199278/intel-core-i510400f-processor-12m-cache-up-to-4-30-ghz/specifications.html) - with 6 total cores.

---

# Stats

## Linux - All Major Versions, Java Types, and Variants

![image](https://user-images.githubusercontent.com/46009390/152651786-853f2f4b-bbc6-4c8e-86cf-23cc3a9b62d9.png)


As shown above, we are able to solve and build all 42 combinations of Linux-based OpenJDK images in 13:34.48 on a single machine.
This is from scratch, i.e. the time taken for SLD resolution + time taken for parallel build with an empty docker build cache.

## Linux - All Major Versions of JDK on slim-bullseye

An example of a typical use case, such as building all versions of JDK on a particular base image:
![image](https://user-images.githubusercontent.com/46009390/152064170-e59cba81-beac-411e-b078-1e64f5f186ed.png)

Again, this is from an empty build cache. We're able to build 5 versions in under 2 minutes.

## Efficiency

We used [dive](https://github.com/wagoodman/dive) which provides an estimate of image efficiency[^1]. All the images we built scored over 95% image efficiency.

![image](https://user-images.githubusercontent.com/46009390/151718407-ba89e8d3-f2be-4ffe-a861-8cbb211395c0.png)

[^1]: Wasted space such as duplicating files across layers count as an 'inefficiency'.

## Compactness

- A [single 315 line file](./linux.Modusfile) holds the conditional logic that defines all the varying image builds.
- In contrast, the templating approach requires a [332 line template file](https://github.com/docker-library/openjdk/blob/c6190d5cbbefd5233c190561fda803f742ae8241/Dockerfile-linux.template), a [77 line script](https://github.com/docker-library/openjdk/blob/abebf9325fea4606b9759fb3b9257ea3eef40061/apply-templates.sh) to apply the template, and a [140 line file](https://github.com/docker-library/bashbrew/blob/master/scripts/jq-template.awk) that defines some helper functions using awk and jq.

# OpenJDK Configuration

Below is a list that shows the ways in which our OpenJDK configuration can 'vary', heavily inspired by the [official approach taken](https://github.com/docker-library/openjdk):
- Major application version
- Full version
- Java Type (JDK vs JRE)
- Base image variants (e.g. bullseye, buster, alpine3.15)
- AMD64 Binary URL
- ARM64 Binary URL
- Source

The variables exposed to a user are (a subset of the above):
- Major application version
- Java Type
- Variant

So a user may request a goal of `openjdk(A, "jdk", "alpine3.15")` to build all versions of JDK on Alpine.

# Disclaimer

The images we generate do not have identical layers. However, their filesystems and behaviour should be very close. Eventually their behaviour should be identical, but the goal is not (necessarily) to have identical *layers*.

In addition, we currently build more images than provided on Docker. So performance may be better than described.

## Notes on Docker's Official Workflow

This attempts to be a tldr for https://github.com/docker-library/official-images,
specific to OpenJDK.
This may not be entirely accurate.

- `update.sh` calls `versions.sh` and `apply-templates.sh`.
- `versions.sh` updates `versions.json`
- `generate-stackbrew-library.sh` generates a summary of the available
images in a well-defined format (shared amongst similar repos).
- `apply-templates.sh` applies the linux/windows Dockerfile template using
jq/awk. This seems to use shared helper functions from bashbrew.
- The GH action jobs are generated using bashbrew, essentially based on
the different combinations of images allowed.

A good short example of an improvement over their template file is https://github.com/docker-library/openjdk/blob/f8d1fd911fdcad985d7a534e3470a9c54c87d45f/Dockerfile-linux.template#L36-L60.

## Note on Multi-Arch

Docker's OpenJDK image creation relies on determining the architecture at runtime.
Which allows them to isolate the logic that is specific to that architecture, and
also, I think, take advantage of `buildx`'s multi platform building (through QEMU).
