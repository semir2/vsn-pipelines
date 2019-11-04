#!/usr/bin/env python3

import argparse
import re
import sys
import pandas as pd
import pickle
from pyscenic import transform
from pyscenic.export import export2loom
from pyscenic.transform import COLUMN_NAME_NES
from pyscenic.utils import COLUMN_NAME_MOTIF_SIMILARITY_QVALUE, COLUMN_NAME_ORTHOLOGOUS_IDENTITY, \
    COLUMN_NAME_ANNOTATION
import time
import utils

################################################################################
# TODO:
# This implementation should be optimized:
# It's taking several hours to run (~5h for ~9k genes and ~13k cells)
################################################################################

parser_grn = argparse.ArgumentParser(description='Run AUCell on gene signatures saved as TSV in folder.')

parser_grn.add_argument(
    'expression_mtx_fname',
    type=argparse.FileType('r'),
    help='The name of the file that contains the expression matrix for the single cell experiment.'
         ' Two file formats are supported: csv (rows=cells x columns=genes) or loom (rows=genes x columns=cells).'
)
parser_grn.add_argument(
    'motif_enrichment_table_fname',
    type=argparse.FileType('r'),
    help='The name of the file that contains the motif enrichments.'
)
parser_grn.add_argument(
    'signatures_fname',
    help='The name of the folder containing the signatures as TSV files.'
)
parser_grn.add_argument(
    'auc_mtx_fname',
    type=argparse.FileType('r'),
    help='The name of the file that contains the AUCell matrix.'
)
parser_grn.add_argument(
    '-o', '--output',
    type=argparse.FileType('w'),
    default=sys.stdout,
    help='Output file/stream, i.e. a table of TF-target genes (CSV).'
)
parser_grn.add_argument(
    '--min-genes-regulon',
    type=int,
    default=5,
    dest="min_genes_regulon",
    help='The threshold used for filtering the regulons based on the number of targets (default: {}).'.format(5)
)
parser_grn.add_argument(
    '--min-regulon-gene-occurrence',
    type=int,
    default=5,
    dest="min_regulon_gene_occurrence",
    help='The threshold used for filtering the genes bases on their occurrence (default: {}).'.format(5)
)
parser_grn.add_argument(
    '--cell-id-attribute',
    type=str,
    default='CellID',
    dest="cell_id_attribute",
    help='The name of the column attribute that specifies the identifiers of the cells in the loom file.'
)
parser_grn.add_argument(
    '--gene-attribute',
    type=str,
    default='Gene',
    dest="gene_attribute",
    help='The name of the row attribute that specifies the gene symbols in the loom file.'
)
parser_grn.add_argument(
    '--title',
    type=str,
    dest="title",
    help='The title for this loom file. If None than the basename of the filename is used as the title.'
)
parser_grn.add_argument(
    '--nomenclature',
    type=str,
    dest="nomenclature",
    help='The name of the genome.'
)
parser_grn.add_argument(
    '--scope-tree-level-1',
    type=str,
    dest="scope_tree_level_1",
    help='The name of the first level of the SCope tree.'
)
parser_grn.add_argument(
    '--scope-tree-level-2',
    type=str,
    dest="scope_tree_level_2",
    help='The name of the second level of the SCope tree.'
)
parser_grn.add_argument(
    '--scope-tree-level-3',
    type=str,
    dest="scope_tree_level_3",
    help='The name of the third level of the SCope tree.'
)

args = parser_grn.parse_args()

print(f"Extracting the matrix form the loom...", flush=True)
start = time.time()
ex_matrix_df = utils.get_matrix(
    loom_file_path=args.expression_mtx_fname.name,
    gene_attribute=args.gene_attribute,
    cell_id_attribute=args.cell_id_attribute
)
print(f"... took {time.time() - start} seconds", flush=True)

# Transform motif enrichment table (generated from the cisTarget step) to regulons
print(f"Reading aggregated motif enrichment table...", flush=True)
start = time.time()
f = args.motif_enrichment_table_fname.name
if f.endswith('.pickle'):
    with open(f, 'rb') as handle:
        motif_enrichment_table = pickle.load(handle)
elif f.endswith('.csv'):
    motif_enrichment_table = utils.read_feature_enrichment_table(fname=args.motif_enrichment_table_fname.name, sep=",")
else:
    raise Exception("The aggregated feature enrichment table is in the wrong format. Expecting .pickle or .csv formats.")
print(f"... took {time.time() - start} seconds to run.", flush=True)

print(f"Making the regulons...", flush=True)
start = time.time()
regulons = transform.df2regulons(
    df=motif_enrichment_table,
    save_columns=[
        COLUMN_NAME_NES,
        COLUMN_NAME_ORTHOLOGOUS_IDENTITY,
        COLUMN_NAME_MOTIF_SIMILARITY_QVALUE,
        COLUMN_NAME_ANNOTATION
    ]
)

# Read the signatures (regulons extracted from AUCell looms generated by AUCell step)
signatures = utils.read_signatures_from_tsv_dir(
    dpath=args.signatures_fname,
    noweights=False,
    weight_threshold=args.min_regulon_gene_occurrence,
    min_genes=args.min_genes_regulon
)

# Filter regulons (regulons from motifs enrichment table) by the filtered signatures
regulons = list(filter(lambda x: x.name in list(map(lambda x: x.name, signatures)), regulons))
# Add gene2occurrence from filtered signatures to regulons
regulons = list(
    map(
        lambda x:
        x.copy(gene2occurrence=list(filter(lambda y: y.name == x.name, signatures))[0].gene2weight), regulons
    )
)
# Rename regulons for SCope
regulons = [r.rename(re.sub(r"\(([+-])\)", r'_(\1)', r.name)) for r in regulons]
print(f"... took {time.time() - start} seconds to run.", flush=True)

print(f"Reading AUCell matrix...", flush=True)
start = time.time()
# Read the regulons AUCell matrix
auc_mtx = pd.read_csv(args.auc_mtx_fname.name, sep='\t', header=0, index_col=0)
# Rename regulons for SCope
auc_mtx.columns = [re.sub(r"\(([+-])\)", r'_(\1)', rname) for rname in auc_mtx.columns]
auc_mtx.columns.name = "Regulon"
print(f"... took {time.time() - start} seconds to run.", flush=True)

# Create loom
print(f"Exporting to loom...", flush=True)
start = time.time()
export2loom(
    ex_mtx=ex_matrix_df,
    regulons=regulons,
    out_fname=args.output.name,
    title=args.title,
    nomenclature=args.nomenclature,
    auc_mtx=auc_mtx,
    tree_structure=[args.scope_tree_level_1, args.scope_tree_level_2, args.scope_tree_level_3],
    compress=True
)
print(f"... took {time.time() - start} seconds to run.", flush=True)
print(f"Done.", flush=True)
