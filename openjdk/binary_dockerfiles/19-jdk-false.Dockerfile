FROM alpine:latest
RUN set -eux; arch="$(apk --print-arch)"; case "$arch" in 'x86_64') downloadUrl='https://download.java.net/java/early_access/jdk19/11/GPL/openjdk-19-ea+11_linux-x64_bin.tar.gz'; ;; 'aarch64') downloadUrl='https://download.java.net/java/early_access/jdk19/11/GPL/openjdk-19-ea+11_linux-aarch64_bin.tar.gz'; ;; *) echo >&2 "error: unsupported architecture: '$arch'"; exit 1 ;; esac; wget -O openjdk.tgz "$downloadUrl";
RUN mkdir -p /opt/openjdk; tar --extract --file openjdk.tgz --directory "/opt/openjdk" --strip-components 1 --no-same-owner ; rm openjdk.tgz*;
