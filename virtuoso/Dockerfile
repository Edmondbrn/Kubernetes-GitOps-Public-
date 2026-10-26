FROM docker.io/openlink/virtuoso-opensource-7:7.2.16
RUN mkdir -p data
# mount data folder directly in the image (avoid hostPath)
COPY ./data /data
# directories need the execute bit to be traversable by a non-root user
RUN chmod -R a+rX /data
CMD ["./virtuoso-entrypoint.sh"]