from google.cloud import storage


def download_blob(bucket_name, source_blob_name, destination_file_name):
    """Downloads a blob from the bucket."""
    # The ID of your GCS bucket
    # bucket_name = "gfs-ensemble-forecast-system"

    # The ID of your GCS object
    # source_blob_name = "storage-object-name"

    # The path to which the file should be downloaded
    # destination_file_name = "local/path/to/file"

    storage_client = storage.Client()

    bucket = storage_client.bucket(bucket_name)

    # Construct a client side representation of a blob.
    # Note `Bucket.blob` differs from `Bucket.get_blob` as it doesn't retrieve
    # any content from Google Cloud Storage. As we don't need additional data,
    # using `Bucket.blob` is preferred here.
    blob = bucket.get_blob(source_blob_name)
    blob.download_to_filename(destination_file_name)

    print(
        "Downloaded storage object {} from bucket {} to local file {}.".format(
            source_blob_name, bucket_name, destination_file_name
        )
    )

bucket_name = "gfs-ensemble-forecast-system"
source_blob_name = "gefs.20241008/00/atmos/pgrb2bp5/gep01.t00z.pgrb2b.0p50.f006"
destination_file_name = "./gep01.t00z.pgrb2b.0p50.f006"
### https://storage.googleapis.com/gfs-ensemble-forecast-system/gefs.20241008/00/atmos/pgrb2bp5/gep01.t00z.pgrb2b.0p50.f006

download_blob(bucket_name,source_blob_name,destination_file_name)

