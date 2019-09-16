version 1.0

import "structs.wdl" as structs
import "tasks/fastqsplitter.wdl" as fastqsplitter
import "tasks/common.wdl" as common
import "tasks/bwa.wdl" as bwa
import "QC/QC.wdl" as qc

workflow Readgroup {
    input {
        Readgroup readgroup
        Library library
        Sample sample
        String readgroupDir
        BwaIndex bwaIndex
        Map[String, String] dockerImages
        String? platform = "illumina"
    }

    # FIXME: workaround for namepace issue in cromwell
    String sampleId = sample.id
    String libraryId = library.id
    String readgroupId = readgroup.id

    # Check MD5sums
    FastqPair reads = readgroup.reads

     if (defined(reads.R1_md5)) {
        call common.CheckFileMD5 as md5CheckR1 {
            input:
                file = reads.R1,
                md5 = select_first([reads.R1_md5])
        }
    }

    if (defined(reads.R2_md5) && defined(reads.R2)) {
        call common.CheckFileMD5 as md5CheckR2 {
            input:
                file = select_first([reads.R2]),
                md5 = select_first([reads.R2_md5])
        }
    }

    call qc.QC as qc {
        input:
            outputDir = readgroupDir,
            read1 = reads.R1,
            read2 = reads.R2,
            dockerImages = dockerImages
    }

    call bwa.Mem as bwaMem {
        input:
            bwaIndex = bwaIndex,
            read1 = qc.qcRead1,
            read2 = qc.qcRead2,
            outputPath = readgroupDir + "/" + basename(reads.R1) + ".bam",
            readgroup = "@RG\\tID:~{sampleId}-~{libraryId}-~{readgroupId}\\tLB:~{libraryId}\\tSM:~{sampleId}\\tPL:~{platform}",
            bwaIndex = bwaIndex,
            dockerImage = dockerImages["bwa+picard"]
    }

    IndexedBamFile bwaBamFile = object {
        file: bwaMem.outputBam,
        index: bwaMem.outputBamIndex
    }

    output {
        FastqPair inputR1 = readgroup.reads
        IndexedBamFile bamFile = bwaBamFile
        Array[File] qcReports = qc.reports
    }
}
