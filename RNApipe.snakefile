#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pandas as pd
import glob
import shutil
import os

##### Load config and sample sheets #####
configfile: "config/config.yaml"

## Read in samplesheet
samples = pd.read_csv(config["samplesheet"], sep='\t')

## Convert all columns to strings
samples = samples.astype(str)

## Concatenate the sequencing directory to Read1 and Read2 for full paths
samples['Read1'] = samples[['Sequencing_Directory', 'Read1']].apply(lambda row: os.path.join(*row), axis=1)
samples['Read2'] = samples[['Sequencing_Directory', 'Read2']].apply(lambda row: os.path.join(*row), axis=1)

## Concatenate columns to identify which groups to run (i.e. Seq_Rep will be run together)
samples['id'] = samples[config['mergeBy']].apply('_'.join, axis=1)

## Set sample names
samples['sn'] = samples[config['fileNamesFrom']].apply('_'.join, axis=1)

## Group by id and extract Read1 & Read2
read1 = samples.groupby('id')['Read1'].apply(list).to_dict()
read2 = samples.groupby('id')['Read2'].apply(list).to_dict()

## Define actions on success
onsuccess:
    ## Success message
    print("RNApipe completed successfully! Wahoo!")

##### Define rules #####
rule all:
	input:
		[expand("output/QC/{sampleName}_{read}_fastqc.{ext}", sampleName=key, read=['R1', 'R2'], ext=['zip', 'html']) for key in samples['sn']]

rule fastqc:
	input:
		read1 = lambda wildcards: read1.get(wildcards.sampleName),
		read2 = lambda wildcards: read2.get(wildcards.sampleName)
	output:
		"output/QC/{sampleName}_R1_fastqc.zip", # temp
		"output/QC/{sampleName}_R2_fastqc.zip", # temp
		"output/QC/{sampleName}_R1_fastqc.html", # temp
		"output/QC/{sampleName}_R2_fastqc.html" # temp
	log:
		err = 'output/logs/fastqc_{sampleName}.err',
		out = 'output/logs/fastqc_{sampleName}.out'
	params:
		dir = "output/QC"
	shell:
		"""
		module load fastqc/0.11.5;
		fastqc -o {params.dir} {input.read1} {input.read2} 1> {log.out} 2> {log.err};
		mv {params.dir}/$(basename {input.read1} .fastq.gz)_fastqc.zip  {params.dir}/{wildcards.sampleName}_R1_fastqc.zip;
		mv {params.dir}/$(basename {input.read2} .fastq.gz)_fastqc.zip  {params.dir}/{wildcards.sampleName}_R2_fastqc.zip;
		mv {params.dir}/$(basename {input.read1} .fastq.gz)_fastqc.html  {params.dir}/{wildcards.sampleName}_R1_fastqc.html;
		mv {params.dir}/$(basename {input.read2} .fastq.gz)_fastqc.html  {params.dir}/{wildcards.sampleName}_R2_fastqc.html
		"""

