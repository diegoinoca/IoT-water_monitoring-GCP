import setuptools

setuptools.setup(
    name='water-quality-telemetry-pipeline',
    version='1.0.0',
    description='Pipeline de Dataflow para procesamiento de telemetría IoT',
    author='Equipo de Investigación',
    install_requires=[
        'apache-beam[gcp]==2.52.0',
        'google-cloud-pubsub==2.18.4',
        'google-cloud-bigquery==3.13.0',
        'google-cloud-storage==2.10.0',
    ],
    packages=setuptools.find_packages(),
    python_requires='>=3.9',
)
