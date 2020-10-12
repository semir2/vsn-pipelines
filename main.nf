import static groovy.json.JsonOutput.*

nextflow.preview.dsl=2

/*
include {
    INIT;
} from './src/utils/workflows/utils' params(params)
INIT()
include {
    SC__FILE_CONVERTER;
} from './src/utils/processes/utils' params(params)

include {
    getDataChannel;
} from './src/channels/channels' params(params)
*/
// run multi-sample with bbknn, output a scope loom file
workflow bbknn {

    include {
        bbknn as BBKNN;
    } from './workflows/bbknn' params(params)
    include {
        PUBLISH as PUBLISH_BBKNN;
    } from "./src/utils/workflows/utils" params(params)

    getDataChannel | BBKNN
    PUBLISH_BBKNN(
        BBKNN.out.scopeloom,
        "BBKNN",
        "loom",
        null,
        false
    )
}

// run multi-sample with mnncorrect, output a scope loom file
workflow mnncorrect {

    include {
        mnncorrect as MNNCORRECT;
    } from './workflows/mnncorrect' params(params)
    include {
        PUBLISH as PUBLISH_MNNCORRECT;
    } from "./src/utils/workflows/utils" params(params)

    getDataChannel | MNNCORRECT
    PUBLISH_MNNCORRECT(
        MNNCORRECT.out.scopeloom,
        "MNNCORRECT",
        "loom",
        null,
        false
    )

}

// run multi-sample with bbknn, output a scope loom file
workflow harmony {

    include {
        harmony as HARMONY;
    } from './workflows/harmony' params(params)
    include {
        PUBLISH as PUBLISH_HARMONY;
    } from "./src/utils/workflows/utils" params(params)

    getDataChannel | HARMONY
    PUBLISH_HARMONY(
        HARMONY.out.scopeloom,
        "HARMONY",
        "loom",
        null,
        false
    )

}

// run multi-sample with bbknn, then scenic from the filtered output:
workflow bbknn_scenic {

    include {
        bbknn as BBKNN;
    } from './workflows/bbknn' params(params)
    include {
        scenic_append as SCENIC_APPEND;
    } from './src/scenic/main' params(params)
    include {
        PUBLISH as PUBLISH_BBKNN_SCENIC;
    } from "./src/utils/workflows/utils" params(params)

    getDataChannel | BBKNN
    SCENIC_APPEND(
        BBKNN.out.filteredloom,
        BBKNN.out.scopeloom
    )
    PUBLISH_BBKNN_SCENIC(
        SCENIC_APPEND.out,
        "BBKNN_SCENIC",
        "loom",
        null,
        false
    )

}

// run multi-sample with harmony, then scenic from the filtered output:
workflow harmony_scenic {

    include {
        harmony as HARMONY;
    } from './workflows/harmony' params(params)
    include {
        scenic_append as SCENIC_APPEND;
    } from './src/scenic/main' params(params)
    include {
        PUBLISH as PUBLISH_HARMONY_SCENIC;
    } from "./src/utils/workflows/utils" params(params)

    getDataChannel | HARMONY
    SCENIC_APPEND(
        HARMONY.out.filteredloom,
        HARMONY.out.scopeloom
    )
    PUBLISH_HARMONY_SCENIC(
        SCENIC_APPEND.out,
        "HARMONY_SCENIC",
        "loom",
        null,
        false
    )

}


// run single_sample, output a scope loom file
workflow single_sample {

    include {
        single_sample as SINGLE_SAMPLE;
    } from './workflows/single_sample' params(params)
    include {
        PUBLISH as PUBLISH_SINGLE_SAMPLE;
    } from "./src/utils/workflows/utils" params(params)

    getDataChannel | SINGLE_SAMPLE
    PUBLISH_SINGLE_SAMPLE(
        SINGLE_SAMPLE.out.scopeloom,
        "SINGLE_SAMPLE",
        "loom",
        null,
        false
    )

}

workflow multi_sample {

    include {
        multi_sample as MULTI_SAMPLE;
    } from './workflows/multi_sample' params(params)

    getDataChannel | MULTI_SAMPLE
    include PUBLISH as PUBLISH_MULTI_SAMPLE from "./src/utils/workflows/utils" params(params)
    PUBLISH_MULTI_SAMPLE(
        MULTI_SAMPLE.out.scopeloom,
        "MULTI_SAMPLE",
        "loom",
        null,
        false
    )

}

// run single_sample, then scenic from the filtered output:
workflow single_sample_scenic {

    include {
        scenic_append as SCENIC_APPEND;
    } from './src/scenic/main' params(params)
    include {
        single_sample as SINGLE_SAMPLE;
    } from './workflows/single_sample' params(params)
    include {
        PUBLISH as PUBLISH_SINGLE_SAMPLE_SCENIC;
    } from "./src/utils/workflows/utils" params(params)

    getDataChannel | SINGLE_SAMPLE
    SCENIC_APPEND(
        SINGLE_SAMPLE.out.filteredloom,
        SINGLE_SAMPLE.out.scopeloom
    )
    PUBLISH_SINGLE_SAMPLE_SCENIC(
        SCENIC_APPEND.out,
        "SINGLE_SAMPLE_SCENIC",
        "loom",
        null,
        false
    )
}

workflow single_sample_scrublet {

    include {
        SINGLE_SAMPLE as SCANPY__SINGLE_SAMPLE;
    } from './src/scanpy/workflows/single_sample' params(params)
    include {
        DOUBLET_REMOVAL as SCRUBLET__DOUBLET_REMOVAL;
    } from "./src/scrublet/workflows/doublet_removal" params(params)

    data = getDataChannel | SC__FILE_CONVERTER
    SCANPY__SINGLE_SAMPLE( data )
    SCRUBLET__DOUBLET_REMOVAL(
        data.join( SCANPY__SINGLE_SAMPLE.out.dr_pca_data ),
        SCANPY__SINGLE_SAMPLE.out.final_processed_data
    )

}

// run single_sample, then scenic from the previous input (not standalone):
workflow pipe_single_sample_scenic {

    take:
        data
    main:
        include {
            scenic_append as SCENIC_APPEND;
        } from './src/scenic/main' params(params)
        include {
            single_sample as SINGLE_SAMPLE;
        } from './workflows/single_sample' params(params)
        include {
            PUBLISH as PUBLISH_P_SINGLE_SAMPLE_SCENIC
        } from "./src/utils/workflows/utils" params(params)

        data | SINGLE_SAMPLE
        SCENIC_APPEND(
            SINGLE_SAMPLE.out.filteredloom,
            SINGLE_SAMPLE.out.scopeloom
        )
        PUBLISH_P_SINGLE_SAMPLE_SCENIC(
            SCENIC_APPEND.out,
            "P_SINGLE_SAMPLE_SCENIC",
            "loom",
            null,
            false
        )

}


// run scenic directly from an existing loom file:
workflow scenic {

    include {
        scenic as SCENIC;
    } from './src/scenic/main' params(params)
    include {
        PUBLISH as PUBLISH_SCENIC;
    } from "./src/utils/workflows/utils" params(params)

    SCENIC(
        Channel.of( tuple(params.global.project_name, file(params.sc.scenic.filteredLoom)))
    )
    PUBLISH_SCENIC(
        SCENIC.out,
        "SCENIC",
        "loom",
        null,
        false
    )

}


// runs mkfastq, then CellRanger count:
workflow cellranger {

    include {
        CELLRANGER;
    } from './src/cellranger/main' params(params)

    CELLRANGER(
        file(params.sc.cellranger.mkfastq.csv),
        file(params.sc.cellranger.mkfastq.runFolder),
        file(params.sc.cellranger.count.transcriptome)
    )

    emit:
        CELLRANGER.out
}

workflow cellranger_libraries {

    include {
        CELLRANGER_LIBRARIES;
    } from './src/cellranger/workflows/cellranger_libraries' params(params)

    CELLRANGER_LIBRARIES(
        file(params.sc.cellranger.mkfastq.csv),
        file(params.sc.cellranger.mkfastq.runFolder),
        file(params.sc.cellranger.count.transcriptome),
        file(params.sc.cellranger.count.featureRef)
    )

    emit:
        CELLRANGER_LIBRARIES.out

}

workflow cellranger_metadata {

    include {
        CELLRANGER_COUNT_WITH_METADATA;
    } from './src/cellranger/workflows/cellRangerCountWithMetadata' params(params)

    CELLRANGER_COUNT_WITH_METADATA(
        file(params.sc.cellranger.count.transcriptome),
        file(params.sc.cellranger.count.metadata)
    )
    emit:
        CELLRANGER_COUNT_WITH_METADATA.out

}

workflow cellranger_metadata_single_sample_scenic {

    cellranger_metadata | \
        map {
            it -> tuple(it[0], it[1], "10x_cellranger_mex", "h5ad")
        } | \
        pipe_single_sample_scenic

}

workflow cellranger_count_libraries {

    include {
        CELLRANGER_COUNT_WITH_LIBRARIES;
    } from './src/cellranger/workflows/cellRangerCountWithLibraries' params(params)

    CELLRANGER_COUNT_WITH_LIBRARIES(
        file(params.sc.cellranger.count.transcriptome),
        file(params.sc.cellranger.count.featureRef),
        params.sc.cellranger.count.libraries
    )

    emit:
        CELLRANGER_COUNT_WITH_LIBRARIES.out

}

workflow freemuxlet {
    include {
        freemuxlet as FREEMUXLET;
    } from './workflows/popscle' params(params)

    getDataChannel | FREEMUXLET
}

workflow demuxlet {
    include {
        demuxlet as DEMUXLET;
    } from './workflows/popscle' params(params)

    getDataChannel | DEMUXLET
}

// runs mkfastq, CellRanger count, then single_sample:
workflow single_sample_cellranger {

    include {
        single_sample as SINGLE_SAMPLE;
    } from './workflows/single_sample' params(params)

    data = cellranger()
    SINGLE_SAMPLE(
        data.map {
            tuple(it[0], it[1], "10x_cellranger_mex", "h5ad")
            }
    )

}

workflow cellranger_multi_sample {

    include {
        multi_sample as MULTI_SAMPLE;
    } from './workflows/multi_sample' params(params)

    data = cellranger()
    MULTI_SAMPLE(
        data.map {
            tuple(it[0], it[1], "10x_cellranger_mex", "h5ad")
            }
    )

}

workflow cellranger_multi_sample_demuxlet {

    include {
        multi_sample as MULTI_SAMPLE;
    } from './workflows/multi_sample' params(params)
    include {
        demuxlet as DEMUXLET;
    } from './workflows/popscle' params(params)

    data = cellranger()
    MULTI_SAMPLE(
        data.map {
            tuple(it[0], it[1], "10x_cellranger_mex", "h5ad")
        }
    )
    DEMUXLET(data)

}

workflow cellranger_libraries_multi_sample {

    include {
        multi_sample as MULTI_SAMPLE;
    } from './workflows/multi_sample' params(params)

    data = cellranger_libraries()
    MULTI_SAMPLE(
        data.map {
            tuple(it[0], it[1], "10x_cellranger_mex", "h5ad")
        }
    )
}

workflow cellranger_libraries_freemuxlet_multi_sample {

    include {
        multi_sample as MULTI_SAMPLE;
    } from './workflows/multi_sample' params(params)
    include {
        freemuxlet as FREEMUXLET;
    } from './workflows/popscle' params(params)

    data = cellranger_libraries()
    MULTI_SAMPLE(
        data.map {
            tuple(it[0], it[1], "10x_cellranger_mex", "h5ad")
            }
    )
    FREEMUXLET(data)

}

workflow cellranger_libraries_demuxlet_multi_sample {

    include {
        multi_sample as MULTI_SAMPLE;
    } from './workflows/multi_sample' params(params)
    include {
        demuxlet as DEMUXLET;
    } from './workflows/popscle' params(params)

    data = cellranger_libraries()
    MULTI_SAMPLE(
        data.map {
            tuple(it[0], it[1], "10x_cellranger_mex", "h5ad")
            }
    )
    DEMUXLET(data)
}

workflow star {

    include {
        star as STAR;
    } from './workflows/star' params(params)
    STAR()

}


workflow single_sample_star {

    include {
        single_sample_star as SINGLE_SAMPLE_STAR;
    } from './workflows/single_sample_star' params(params)

    SINGLE_SAMPLE_STAR()

}

workflow nemesh {

    include {
        nemesh as NEMESH;
    } from './workflows/nemesh' params(params)

    NEMESH()

}

workflow sra_cellranger_bbknn {

    main:
        include {
            getChannel as getSRAChannel;
        } from './src/channels/sra' params(params)
        include {
            DOWNLOAD_FROM_SRA;
        } from './src/utils/workflows/downloadFromSRA' params(params)
        include {
            SC__CELLRANGER__PREPARE_FOLDER;
            SC__CELLRANGER__COUNT;
        } from './src/cellranger/processes/utils' params(params)
        include {
            bbknn as BBKNN;
        } from './workflows/bbknn' params(params)

        // Run
        DOWNLOAD_FROM_SRA( getSRAChannel( params.data.sra ) )
        SC__CELLRANGER__PREPARE_FOLDER( DOWNLOAD_FROM_SRA.out.groupTuple() )
        SC__CELLRANGER__COUNT(
            file(params.sc.cellranger.count.transcriptome),
            SC__CELLRANGER__PREPARE_FOLDER.out
        )
        BBKNN(
            SC__CELLRANGER__COUNT.out.map {
                it -> tuple(it[0], it[1], "10x_cellranger_mex", "h5ad")
            }
        )

    emit:
        filteredLoom = BBKNN.out.filteredloom
        scopeLoom = BBKNN.out.scopeloom

}

workflow sra_cellranger_bbknn_scenic {

    include {
        scenic_append as SCENIC_APPEND;
    } from './src/scenic/main' params(params)
    include {
        PUBLISH as PUBLISH_SRA_CELLRANGER_BBKNN_SCENIC;
    } from "./src/utils/workflows/utils" params(params)

    sra_cellranger_bbknn()
    SCENIC_APPEND(
        sra_cellranger_bbknn.out.filteredLoom,
        sra_cellranger_bbknn.out.scopeLoom
    )
    PUBLISH_SRA_CELLRANGER_BBKNN_SCENIC(
        SCENIC_APPEND.out,
        "SRA_CELLRANGER_BBKNN_SCENIC",
        "loom",
        null,
        false
    )

}

workflow hashtags_rnaseq {
	include {
		run_HTO
	} from './src/Seurat/workflows/HTO.nf' params(params)
	include {
		R_rnaseq
	} from './workflows/R_rnaseq.nf' params(params)

	input = Channel.fromPath(params.Seurat.seuratObjBuilder.inputFile)
					.map{ file -> tuple(params.global.sampleName,file)}
	run_HTO(input)
	R_rnaseq(run_HTO.out)
}

workflow hashtags_citeseq {

	include {
		run_HTO
	} from './src/Seurat/workflows/HTO.nf' params(params)
	include {
		R_rnaseq
	} from './workflows/R_rnaseq.nf' params(params)
	include {
		run_ADT
	} from './src/Seurat/workflows/ADT.nf' params(params)

	input = Channel.fromPath(params.Seurat.seuratObjBuilder.inputFile)
					.map{ file -> tuple(params.global.sampleName,file)}
	run_HTO(input)
	R_rnaseq(run_HTO.out)
	run_ADT(R_rnaseq.out)
}

workflow citeseq {

	include {
		R_rnaseq
	} from './workflows/R_rnaseq.nf' params(params)
	include {
		run_ADT
	} from './src/Seurat/workflows/ADT.nf' params(params)
	include {
		SEURAT__SEURAT_OBJECT_BUILDER
	} from './src/Seurat/processes/seuratObjBuilder/seuratObjBuilder.nf' params(params)

	if(params.Seurat.seuratObjBuilder.inputFile == null){
		seuratInput = Channel.fromPath(params.Seurat.inputRdsFile)
						.map{ file -> tuple(params.global.sampleName,file)}
	} else {
		input = Channel.fromPath(params.Seurat.seuratObjBuilder.inputFile)
						.map{ file -> tuple(params.global.sampleName,file)}
		seuratInput = SEURAT__SEURAT_OBJECT_BUILDER(input)
	}


	R_rnaseq(seuratInput)
	run_ADT(R_rnaseq.out)
}

workflow rnaseq {
	include {
		R_rnaseq
	} from './workflows/R_rnaseq.nf' params(params)

	include {
		SEURAT__SEURAT_OBJECT_BUILDER
	} from './src/Seurat/processes/seuratObjBuilder/seuratObjBuilder.nf' params(params)

	if(params.Seurat.seuratObjBuilder.inputFile == null){
		seuratInput = Channel.fromPath(params.Seurat.inputRdsFile)
						.map{ file -> tuple(params.global.sampleName,file)}
	} else {
		input = Channel.fromPath(params.Seurat.seuratObjBuilder.inputFile)
						.map{ file -> tuple(params.global.sampleName,file)}
		seuratInput = SEURAT__SEURAT_OBJECT_BUILDER(input)
	}

	R_rnaseq(seuratInput)
}
