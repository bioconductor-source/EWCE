#' check_ewce_genelist_inputs
#'
#' \code{check_ewce_genelist_inputs} Is used to check that hits and bg gene
#' lists passed to EWCE are setup correctly. Checks they are the
#' appropriate length.
#' Checks all hits genes are in bg. Checks the species match and if not
#' reduces to 1:1 orthologs.
#' @param standardise If \code{input_species==output_species},
#' should the genes be standardised using \link[orthogene]{map_genes}?
#' @inheritParams bootstrap_enrichment_test
#'
#' @return A list containing
#' \itemize{
#'   \item \code{hits}: Array of MGI/HGNC gene symbols containing the target
#'   gene list.
#'   \item \code{bg}: Array of MGI/HGNC gene symbols containing the background
#'   gene list.
#' }
#'
#' @examples
#' ctd <- ewceData::ctd()
#' example_genelist <- ewceData::example_genelist()
#'
#' # Called from "bootstrap_enrichment_test()" and "generate_bootstrap_plots()"
#' checkedLists <- EWCE::check_ewce_genelist_inputs(
#'     sct_data = ctd,
#'     hits = example_genelist,
#'     sctSpecies = "mouse",
#'     genelistSpecies = "human"
#' )
#' @export
#' @importFrom orthogene create_background map_genes map_orthologs
check_ewce_genelist_inputs <- function(sct_data,
    hits,
    bg = NULL,
    genelistSpecies = NULL,
    sctSpecies = NULL,
    output_species = "human",
    geneSizeControl = FALSE,
    standardise = FALSE,
    verbose = TRUE) {
    messager("Checking gene list inputs.", v = verbose)
    #### Check species ####
    species <- check_species(
        genelistSpecies = genelistSpecies,
        sctSpecies = sctSpecies,
        verbose = verbose
    )
    genelistSpecies <- species$genelistSpecies
    sctSpecies <- species$sctSpecies
    # geneSizeControl assumes the genesets are from human genetics...
    # so genelistSpecies must equal "human"
    if (isTRUE(geneSizeControl) &
        (genelistSpecies != "human")) {
        err_msg6 <- paste0(
            "geneSizeControl assumes the genesets are from",
            " human genetics... so genelistSpecies must be set to",
            " 'human'"
        )
        stop(err_msg6)
    }
    #### Create background if none provided ####
    # Keep internal bc it has a check_species beforehand
    bg <- orthogene::create_background(
        species1 = sctSpecies,
        species2 = genelistSpecies,
        output_species = output_species,
        bg = bg,
        verbose = verbose
    )
    #### Convert CTD ####
    #### Standardise sct_data ####
    messager("Standardising sct_data.", v = verbose)
    if (sctSpecies != output_species) {
        sct_data <- standardise_ctd(
            ctd = sct_data,
            input_species = sctSpecies,
            output_species = output_species,
            dataset = "sct_data",
            verbose = FALSE
        )
    }
    sct_genes <- unname(rownames(sct_data[[1]]$mean_exp))
    ##### Convert hits to (human) ####
    messager("Converting gene list input to standardised",
        output_species, "genes.",
        v = verbose
    )
    hits <- unique(as.character(hits))
    if (genelistSpecies == output_species && isTRUE(standardise)) {
        hits <- orthogene::map_genes(
            genes = hits,
            species = genelistSpecies,
            drop_na = TRUE,
            verbose = FALSE
        )$name
    } else {
        hits <- orthogene::map_orthologs(
            genes = hits,
            input_species = genelistSpecies,
            output_species = output_species,
            method = "homologene",
            verbose = FALSE
        )$ortholog_gene
    }
    #### Check that all 'hits' are in 'bg' ####
    hits <- hits[hits %in% bg]
    if (sum(!hits %in% bg, na.rm = TRUE) > 0) {
        stop("All hits must be in bg.")
    }
    #### Check that all 'sct_genes' are in 'bg' ####
    sct_genes <- sct_genes[sct_genes %in% bg]
    if (sum(!sct_genes %in% bg, na.rm = TRUE) > 0) {
        stop("All hits must be in bg.")
    }
    #### Check that sufficient genes are still present in the target list ####
    if (length(hits) < 4) {
        err_msg5 <- paste0(
            "At least four genes which are present in the",
            " single cell dataset & background gene set are",
            " required to test for enrichment."
        )
        stop(err_msg5)
    }
    #### Restrict gene sets to only genes in the SCT dataset  ####
    if (!geneSizeControl) {
        hits <- hits[hits %in% sct_genes]
        bg <- bg[bg %in% sct_genes]
    }
    #### Remove all hit genes from bg ####
    bg <- bg[!bg %in% hits]
    #### Return list ####
    return(list(
        hits = hits,
        sct_genes = sct_genes,
        sct_data = sct_data,
        bg = bg,
        genelistSpecies = genelistSpecies,
        sctSpecies = sctSpecies,
        output_species = output_species
    ))
}
