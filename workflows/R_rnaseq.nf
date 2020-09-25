nextflow.preview.dsl=2

include {
	SEURAT__RNA_QC
} from '../src/Seurat/processes/RNAQc/RNAQc.nf' params(params)

include {
	SEURAT__THRESHOLDFILTERING
} from '../src/Seurat/processes/thresholdFiltering/thresholdFiltering.nf' params(params)

include {
	SEURAT__SEURAT_TO_SCE
} from '../src/Seurat/processes/utils/convertion.nf' params(params)

include {
	SINGLE_CELL_EXPERIMENT__NORMALIZATION
} from  '../src/SingleCellExperiment/processes/normalization/normalization.nf' params(params)

include {
	SINGLE_CELL_EXPERIMENT__PCA_FILTERING
} from  '../src/SingleCellExperiment/processes/pcaFiltering/pcaFiltering.nf' params(params)

workflow R_rnaseq {
	take : seuratInput
	main :
		SEURAT__RNA_QC(seuratInput)
		SEURAT__THRESHOLDFILTERING(SEURAT__RNA_QC.out[0])
		SEURAT__SEURAT_TO_SCE(SEURAT__THRESHOLDFILTERING.out[0])
		SINGLE_CELL_EXPERIMENT__PCA_FILTERING(SEURAT__SEURAT_TO_SCE.out)
		SINGLE_CELL_EXPERIMENT__NORMALIZATION(SINGLE_CELL_EXPERIMENT__PCA_FILTERING.out[0])

}
