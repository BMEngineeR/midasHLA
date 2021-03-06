#' Check HLA allele format
#'
#' \code{checkAlleleFormat} test if the input character follows HLA nomenclature
#' specifications.
#'
#' Correct HLA number should consist of HLA gene name followed by "*" and sets
#' of digits separated with ":". Maximum number of sets of digits is 4 which
#' is termed 8-digit resolution. Optionally HLA numbers can be supplemented with
#' additional suffix indicating its expression status. See
#' \url{http://hla.alleles.org/nomenclature/naming.html} for more details.
#'
#' HLA alleles with identical sequences across exons encoding the peptide
#' binding domains might be designated with G group allele numbers. Those
#' numbers have additional G or GG suffix. See
#' \url{http://hla.alleles.org/alleles/g_groups.html} for more details. They are
#' interpreted as valid HLA alleles designations.
#'
#' @param allele Character vector with HLA allele numbers.
#'
#' @return Logical vector specifying if \code{allele} elements follows HLA
#'   alleles naming conventions.
#'
#' @examples
#' allele <- c("A*01:01", "A*01:02")
#' checkAlleleFormat(allele)
#'
#' @importFrom assertthat assert_that
#' @importFrom stringi stri_detect_regex
#' @export
checkAlleleFormat <- function(allele) {
  pattern <- "^[A-Z0-9]+[*][0-9]+(:[0-9]+){0,3}((?=G)(G|GG)|(N|L|S|C|A|Q)){0,1}$"
  is_correct <- stri_detect_regex(allele, pattern)
  return(is_correct)
}

#' Infer HLA allele resolution
#'
#' \code{getAlleleResolution} returns the resolution of input HLA allele
#' numbers.
#'
#' HLA allele resolution can take the following values: 2, 4, 6, 8. See
#' \url{http://hla.alleles.org/nomenclature/naming.html} for more details.
#'
#' \code{NA} values are accepted and returned as \code{NA}.
#'
#' @inheritParams checkAlleleFormat
#'
#' @return Integer vector specifying allele resolutions.
#'
#' @examples
#' allele <- c("A*01:01", "A*01:02")
#' getAlleleResolution(allele)
#'
#' @importFrom assertthat assert_that see_if
#' @importFrom stringi stri_count_fixed
#' @export
getAlleleResolution <- function(allele) {
  assert_that(
    see_if(all(checkAlleleFormat(allele), na.rm = TRUE),
         msg = "allele have to be a valid HLA allele number"
    )
  )
  allele_resolution <- 2 * (stri_count_fixed(allele, ":") + 1)
  return(allele_resolution)
}

#' Reduce HLA alleles
#'
#' \code{reduceAlleleResolution} reduce HLA allele numbers resolution.
#'
#' In cases when allele number contain additional suffix their resolution
#' can not be unambiguously reduced. These cases are returned unchanged.
#' Function behaves in the same manner if \code{resolution} is higher than
#' resolution of input HLA allele numbers.
#'
#' \code{NA} values are accepted and returned as \code{NA}.
#'
#' TODO here we give such warning when alleles have G or GG suffix (see
#' http://hla.alleles.org/alleles/g_groups.html)
#'   "Reducing G groups alleles, major allele gene name will be used."
#' I dond't really remember why we are doing this xd These allele numbers are
#' processed as normal alleles (without suffix). Let me know if this warning is
#' relevant or we could go without it. If we want to leave it lets also add text
#' in documentation.
#'
#' @inheritParams checkAlleleFormat
#' @param resolution Number specifying desired resolution.
#'
#' @return Character vector containing reduced HLA allele numbers.
#'
#' @examples
#' reduceAlleleResolution(c("A*01", "A*01:24", "C*05:24:55:54"), 2)
#'
#' @importFrom assertthat assert_that is.count see_if
#' @importFrom stringi stri_split_fixed stri_detect_regex
#' @importFrom rlang warn
#' @export
reduceAlleleResolution <- function(allele,
                                   resolution=4) {
  assert_that(
    see_if(all(checkAlleleFormat(allele), na.rm = TRUE),
           msg = "allele have to be a valid HLA allele number"
    ),
    is.count(resolution)
  )
  na_idx <- is.na(allele)
  letter_alleles <- stri_detect_regex(allele, pattern = "(N|L|S|C|A|Q){1}$")
  is_ggroup <- stri_detect_regex(allele, pattern = "(G|GG){1}$")
  allele_res <- getAlleleResolution(allele)
  to_reduce <- allele_res > resolution & ! letter_alleles & ! na_idx
  resolution <- floor(resolution) / 2
  if (any(is_ggroup & to_reduce)) {
    warn("Reducing G groups alleles, major allele gene name will be used.")
  }
  allele[to_reduce] <- vapply(
    X = stri_split_fixed(allele[to_reduce], ":"),
    FUN = function(a) {
      paste(a[seq_len(resolution)], collapse = ":")
    },
    FUN.VALUE = character(length = 1)
  )
  allele[na_idx] <- NA
  return(allele)
}

#' Find variable positions in sequence alignment
#'
#' \code{getVariableAAPos} finds variable amino acid positions in protein
#' sequence alignment.
#'
#' The variable amino acid positions in the alignment are those at which
#' different amino acids can be found. As the alignments can also contain indels
#' and unknown characters, the user choice might be to consider those positions
#' as variable or not. This can be achieved by passing appropriate regular
#' expression in \code{varchar}. Eg. when \code{varchar = "[A-Z]"} occurence of
#' deletion/insertion (".") will not be treated as variability. In order to
#' detect this kind of variability \code{varchar = "[A-Z\\\\.]"} should be used.
#'
#' @param alignment Matrix containing amino acid level alignment, as returned by
#'   \code{\link{readHlaAlignments}},
#' @param varchar Regex matching characters that should be considered when
#'   looking for variable amino acid positions. See details for further
#'   explanations.
#'
#' @return Integer vector specifying which alignment columns are variable.
#'
#' @examples
#' alignment <- readHlaAlignments(gene = "TAP1")
#' getVariableAAPos(alignment)
#'
#' @importFrom assertthat assert_that is.count see_if
#' @export
getVariableAAPos <- function(alignment,
                             varchar = "[A-Z]") {
  assert_that(is.matrix(alignment))
  var_cols <- apply(alignment,
        2,
        function(col) {
          col <- col[grepl(sprintf("^%s$", varchar), col)]
          is.variable <- logical(length = 1)
          if (length(col) == 0) {
            is.variable <- FALSE
          } else {
            is.variable <- any(col != col[1])
          }
          return(is.variable)
        }
  )
  return(which(var_cols))
}

#' Convert allele numbers to additional variables
#'
#' \code{convertAlleleToVariable} converts input HLA allele numbers to additional
#' variables based on the supplied dictionary.
#'
#' \code{dictionary} file should be a tsv format with header and two columns.
#' First column should hold allele numbers, second additional variables (eg.
#' expression level).
#'
#' Type of the returned vector depends on the type of the additional variable.
#'
#' @inheritParams checkAlleleFormat
#' @param dictionary Path to file containing HLA allele dictionary or a
#'   data frame.
#'
#' @return Vector containing HLA allele numbers converted to additional
#'   variables according to \code{dictionary}.
#'
#' @examples
#' dictionary <- system.file("extdata", "Match_allele_HLA_supertype.txt", package = "midasHLA")
#' convertAlleleToVariable(c("A*01:01", "A*02:01"), dictionary = dictionary)
#'
#' @importFrom assertthat assert_that is.string is.readable see_if
#' @importFrom stats setNames
#' @importFrom utils read.table
#' @export
convertAlleleToVariable <- function(allele,
                                    dictionary) {
  assert_that(
    see_if(all(checkAlleleFormat(allele), na.rm = TRUE),
           msg = "allele have to be a valid HLA allele number"
    ),
    see_if(is.string(dictionary) | is.data.frame(dictionary),
           msg = "dictionary have to be either a path or a data.frame"
    )
  )
  if (is.character(dictionary)) {
    assert_that(
      is.readable(dictionary)
    )
    dictionary <- read.table(
      file = dictionary,
      header = TRUE,
      sep = "\t",
      stringsAsFactors = FALSE
    )
  }
  assert_that(
    see_if(ncol(dictionary) == 2,
           msg = "dictionary must have two columns"
    ),
    see_if(all(checkAlleleFormat(dictionary[, 1]), na.rm = TRUE),
           msg = "first column in dictionary must contain valid HLA allele numbers"
    ),
    see_if(! any(duplicated(dictionary[, 1]), na.rm = TRUE),
           msg = "dictionary contains duplicated allele numbers")
  )
  dictionary <- setNames(dictionary[, 2], dictionary[, 1])
  variable <- dictionary[as.character(allele)] # for all NAs vectrors default type is logical; recycling mechanism leads to unwanted results
  names(variable) <- NULL

  return(variable)
}

#' Backquote character
#'
#' \code{backquote} places backticks around elements of character vector
#'
#' \code{backquote} is useful when using HLA allele numbers in formulas, where
#' \code{'*'} and \code{':'} characters have special meanings.
#'
#' @param x Character vector.
#'
#' @return Character vector with its elements backticked.
#'
#' @importFrom assertthat assert_that
#'
backquote <- function(x) {
  assert_that(is.character(x))
  x <- gsub("`", "", x)
  backquoted <- paste0("`", x, "`")
  return(backquoted)
}

#' Extend and Re-fit a Model Call
#'
#' \code{updateModel} adds new variables to model and re-fit it.
#'
#' @param object An existing fit from a model function such as lm, glm and many
#'   others.
#' @param x Character vector specifying variables to be added to model.
#' @param placeholder String specifying term to substitute with value from
#'   \code{x}. Ignored if set to \code{NULL}.
#' @param backquote Logical indicating if added variables should be quoted.
#'   Elements of this vector are recycled over \code{x}.
#' @param collapse String specifying how variables should be combined. Defaults
#'   to \code{" + "} ie. linear combination.
#'
#' @return Updated fitted object.
#'
#' @importFrom assertthat assert_that is.string
#' @importFrom magrittr %>%
#' @importFrom stats update
#'
updateModel <- function(object,
                        x,
                        placeholder = NULL,
                        backquote = TRUE,
                        collapse = " + ") {
  assert_that(
    checkStatisticalModel(object),
    is.character(x),
    isStringOrNULL(placeholder),
    isTRUEorFALSE(backquote),
    is.string(collapse)
  )

  object_env <- attr(object$terms, ".Environment")

  if (backquote) {
    x <- backquote(x)
  }

  if (is.null(placeholder)) {
    x <- paste0(". ~ . + ", paste(x, collapse = collapse))
  } else {
    x <- paste0("(", paste(x, collapse = collapse), ")")
    object_call <- getCall(object)
    object_form <- object_call[["formula"]] %>%
      eval(envir = object_env)
    assert_that(
      objectHasPlaceholder(object, placeholder = placeholder)
    )
    x <- gsub(pattern = placeholder, replacement = x, x = deparse(object_form))
  }

  new_object <- update(object = object, x, evaluate = FALSE)
  new_object <- eval(new_object, envir = object_env)

  return(new_object)
}

#' List HLA alleles dictionaries
#'
#' \code{listMiDASDictionaries} lists dictionaries shipped with the MiDAS package.
#' See \code{\link{hlaToVariable}} for more details on dictionaries.
#'
#' @param file.names Logical value. If FALSE, only the names of dictionaries are
#' returned. If TRUE their paths are returned.
#' @param pattern String used to match dictionary names, it can be a regular
#'   expression. By default all names are matched.
#'
#' @return Character vector giving names of available HLA alleles dictionaries.
#'
listMiDASDictionaries <- function(pattern = "allele", file.names = FALSE) {
  pattern <- paste0("^Match.*", pattern, ".*.txt$")
  lib <- list.files(
    path = system.file("extdata", package = "midasHLA"),
    pattern = pattern,
    full.names = file.names
  )

  if (! file.names) {
    lib <- gsub("^Match_", "", gsub(".txt$", "", lib))
  }

  return(lib)
}

#' Likelihood ratio test
#'
#' \code{LRTest} carry out an asymptotic likelihood ratio test for two models.
#'
#' \code{mod0} have to be a reduced version of \code{mod1}. See examples.
#'
#' @param mod0 An existing fit from a model function such as lm, glm and many
#'   others.
#' @param mod1 Object of the same class as \code{mod0} with extra terms
#'   included.
#'
#' @return Data frame with the results of likelihood ratio test of the supplied
#'   models.
#'
#'   Column \code{term} holds new variables appearing in \code{mod1},
#'   \code{df} difference in degrees of freedom between models, \code{logLik}
#'   difference in log likelihoods, \code{statistic} \code{Chisq} statistic and
#'   \code{p.value} corresponding p-value.
#'
#' @importFrom assertthat assert_that
#' @importFrom rlang abort warn
#' @importFrom stats logLik pchisq
#'
LRTest <- function(mod0, mod1) {
  formula0 <- formula(mod0)
  vars0 <- all.vars(formula0)
  formula1 <- formula(mod1)
  vars1 <- all.vars(formula1)
  assert_that(
    all(vars0 %in% vars1),
    msg = sprintf("variables %s were not found in mod1",
                  paste(vars0[! vars0 %in% vars1], collapse = ", ")
    )
  )
  
  # drop vars with NA coefficient
  coefs <- stats::coef(mod1)
  na_vars <- names(coefs)[is.na(coefs)]
  if (length(na_vars)) {
    warning(sprintf(
      "Coefficients for variables: %s could not be estimated, those variables will not be included in likelyhood ratio test result.",
      paste(na_vars, collapse = ",")
    ))
    vars1 <- vars1[! vars1 %in% na_vars]
  }

  new_vars <- vars1[! vars1 %in% vars0]
  if (! length(new_vars)) {
    stop("No new variables found in an extended model. Likely coefficients for new variables could not be estimated, please check previous warning messages.",
         domain = NA
    )
  }
  
  # df <- length(new_vars) - 1
  # according to this post https://stackoverflow.com/questions/37917437/loglik-lm-why-does-r-use-p-1-instead-of-p-for-degree-of-freedom
  # df <- attr(ll1, "df") - attr(ll0, "df") is proper
  ll0 <- logLik(mod0)
  ll1 <- logLik(mod1)
  df <- attr(ll1, "df") - attr(ll0, "df")
  
  statistic <- 2 * (as.numeric(ll1) - as.numeric(ll0))
  p.value <- pchisq(statistic, df = df, lower.tail=FALSE)

  
  res <- data.frame(
    term = paste(new_vars, collapse = ", "),
    df = df,
    logLik = ll1 - ll0,
    statistic = statistic,
    p.value = p.value,
    stringsAsFactors = FALSE
  )

  return(res)
}

#' Get attributes of statistical model object
#'
#' \code{getObjectDetails} extracts some of the statistical model object
#' attributes that are needed for \code{runMiDAS} internal calculations.
#'
#' @inheritParams checkStatisticalModel
#'
#' @return List with following elements:
#' \describe{
#'   \item{call}{Object's call}
#'   \item{formula_vars}{Character containing names of variables in object
#'     formula}
#'   \item{data}{MiDAS object associated with model}
#' }
#'
#' @importFrom MultiAssayExperiment colData
#'
getObjectDetails <- function(object) {
  object_call <- getCall(object)
  object_env <- attr(object$terms, ".Environment")
  object_formula <- eval(object_call[["formula"]], envir = object_env)
  object_call[["formula"]] <- object_formula
  object_data <- eval(object_call[["data"]], envir = object_env)

  object_details <- list(
    call = object_call,
    formula_vars = all.vars(object_formula),
    data = object_data
  )

  return(object_details)
}

#' Get variables frequencies from MiDAS
#'
#' Helper getting variables frequencies from MiDAS object. Additionally for
#' binary test covariate frequencies per phenotype are added. Used in scope of 
#' \code{runMiDAS}.
#'
#' @param midas MiDAS object.
#' @param experiment String specifying experiment from \code{midas}.
#' @param test_covar String giving name of test covariate.
#'
#' @return Data frame with variable number of columns. First column,
#'   \code{"term"} holds experiment's variables, further columns hold number of
#'   variable occurrence and their frequencies.
#'
#' @importFrom dplyr filter left_join mutate rename select
#' @importFrom formattable percent
#' @importFrom magrittr %>%
#' @importFrom rlang !! :=
#' @importFrom stats na.omit
#'
runMiDASGetVarsFreq <- function(midas, experiment, test_covar) {
  variables_freq <- midas[[experiment]] %>%
    getExperimentFrequencies() %>%
    mutate(Freq = percent(.data$Freq)) %>%
    rename(Ntotal = .data$Counts, Ntotal.percent = .data$Freq)

  test_covar_vals <- factor(colData(midas)[[test_covar]])
  if (nlevels(test_covar_vals) == 2) {
    ids <- rownames(colData(midas))

    lvl1_ids <- ids[test_covar_vals == levels(test_covar_vals)[1]] %>% 
      na.omit()
    lvl1_freq <- midas[, lvl1_ids] %>%
      `[[`(experiment) %>%
      getExperimentFrequencies() %>%
      mutate(Freq = percent(.data$Freq)) %>%
      rename(
        !!sprintf("N(%s=%s)", test_covar, levels(test_covar_vals)[1]) := .data$Counts,
        !!sprintf("N(%s=%s).percent", test_covar, levels(test_covar_vals)[1]) := .data$Freq
      )
    variables_freq <- left_join(variables_freq, lvl1_freq, by = "term")

    lvl2_ids <- ids[test_covar_vals == levels(test_covar_vals)[2]] %>%
      na.omit()
    lvl2_freq <- midas[, lvl2_ids] %>%
      `[[`(experiment) %>%
      getExperimentFrequencies() %>%
      mutate(Freq = percent(.data$Freq)) %>%
      rename(
        !!sprintf("N(%s=%s)", test_covar, levels(test_covar_vals)[2]) := .data$Counts,
        !!sprintf("N(%s=%s).percent", test_covar, levels(test_covar_vals)[2]) := .data$Freq
      )
    variables_freq <- left_join(variables_freq, lvl2_freq, by = "term")
  }

  return(variables_freq)
}

#' Calculate Grantham distance between amino acid sequences
#'
#' \code{distGrantham} calculates normalized Grantham distance between two
#' amino acid sequences. For details on calculations see
#' \href{http://www.sciencemag.org/content/185/4154/862.long}{Grantham R. 1974.}.
#'
#' Distance between amino acid sequences is normalized by length of compared
#' sequences.
#'
#' Lengths of \code{aa1} and \code{aa2} must be equal.
#'
#' @param aa1 Character vector giving amino acid sequence using one letter
#'   codings. Each element must correspond to single amino acid.
#' @param aa2 Character vector giving amino acid sequence using one letter
#'   codings. Each element must correspond to single amino acid.
#'
#' @return Numeric vector of normalized Grantham distance between \code{aa1} and
#'   \code{aa2}.
#'
#' @importFrom assertthat assert_that see_if
#'
distGrantham <- function(aa1, aa2) {
  assert_that(
    is.character(aa1),
    is.character(aa2),
    see_if(
      length(aa1) == length(aa2),
      msg = "aa1 and aa2 must have equal lengths."
    )
  )

  idx <- paste(aa1, aa2, sep = "")
  assert_that(
    all(test <- idx %in% names(dict_dist_grantham)),
    msg = sprintf(
      fmt = "%s are not valid amino acids pairs",
      paste(idx[! test], collapse = ", ")
    )
  )

  d <- sum(dict_dist_grantham[idx]) / length(idx)

  return(d)
}

#' Calculate Grantham distance between HLA alleles
#'
#' \code{hlaCallsGranthamDistance} calculate Grantham distance between two HLA
#' alleles of a given, using original formula by
#' \href{http://www.sciencemag.org/content/185/4154/862.long}{Grantham R. 1974.}.
#'
#' Grantham distance is calculated only for class I HLA alleles. First
#' exons forming the variable region in the peptide binding groove are selected.
#' Here we provide option to choose either  \code{"binding_groove"} - exon 2 and
#' 3 (positions 1-182 in IMGT/HLA alignments, however here we take 2-182 as many
#' 1st positions are missing), \code{"B_pocket"} -  residues 7, 9, 24, 25, 34,
#' 45, 63, 66, 67, 70, 99 and \code{"F_pocket"} - residues 77, 80, 81, 84, 95,
#' 116, 123, 143, 146, 147. Then all the alleles containing gaps, stop codons or
#' indels are discarded. Finally distance is calculated for each pair.
#'
#' See \href{https://europepmc.org/article/med/28650991}{Robinson J. 2017.} for
#' more details on the choice of exons 2 and 3.
#'
#' @inheritParams checkHlaCallsFormat
#' @param genes Character vector specifying genes for which allelic distance
#'   should be calculated.
#' @param aa_selection String specifying variable region in peptide binding
#'   groove which should be considered for Grantham distance calculation. Valid
#'   choices includes: \code{"binding_groove"}, \code{"B_pocket"},
#'   \code{"F_pocket"}. See details for more information.
#'
#' @return Data frame of normalized Grantham distances between pairs of alleles
#'   for each specified HLA gene. First column (\code{ID}) is the same as in
#'   \code{hla_calls}, further columns are named as given by \code{genes}.
#'
#' @examples
#' hlaCallsGranthamDistance(MiDAS_tut_HLA, genes = "A")
#'
#' @importFrom assertthat assert_that is.string noNA see_if
#' @importFrom magrittr %>%
#' @importFrom rlang warn
#' @importFrom stats na.omit
#' @export
hlaCallsGranthamDistance <- function(hla_calls,
                                     genes = c("A", "B", "C"),
                                     aa_selection = "binding_groove") {
  assert_that(
    checkHlaCallsFormat(hla_calls),
    is.character(genes),
    noNA(genes),
    stringMatches(aa_selection, c("binding_groove", "B_pocket", "F_pocket"))
  )

  target_genes <- getHlaCallsGenes(hla_calls)
  assert_that(
    characterMatches(x = genes, choice = target_genes)
  )
  target_genes <- genes

  d <- list(ID = hla_calls[, 1, drop = TRUE])
  for (gene in target_genes) {
    if (! gene %in% c("A", "B", "C")) {
      warn(sprintf("Grantham distance is calculated only for class I HLA alleles. Omitting gene %s", gene))
      next()
    }

    sel <- paste0(gene, c("_1", "_2"))
    pairs <- hla_calls[, sel]
    resolution <- getAlleleResolution(unlist(pairs)) %>%
      na.omit()
    assert_that( # this should become obsolete
      see_if(
        all(resolution == resolution[1]),
        msg = sprintf("Allele resolutions for gene %s are not equal", gene)
      )
    )

    # process alignment
    aa_sel <- list(
      binding_groove = 2:182,
      B_pocket =  c(7, 9, 24, 25, 34, 45, 63, 66, 67, 70, 99),
      F_pocket = c(77, 80, 81, 84, 95, 116, 123, 143, 146, 147)
    )
    alignment <- hlaAlignmentGrantham(gene, resolution[1], aa_sel[[aa_selection]])

    allele_numbers <- rownames(alignment)
    d[[gene]] <- vapply(
      X = seq_len(nrow(pairs)),
      FUN = function(i) {
        allele1 <- pairs[i, 1]
        allele2 <- pairs[i, 2]
        if (allele1 %in% allele_numbers && allele2 %in% allele_numbers) {
          aa1 <- alignment[allele1, ]
          aa2 <- alignment[allele2, ]
          distGrantham(aa1, aa2)
        } else {
          warn(
            sprintf(
              fmt = "Alleles %s could not be found in the alignment coercing to NA",
              paste(allele1, allele1, sep = ", ")
            )
          )
          as.numeric(NA)
        }
      },
      FUN.VALUE = numeric(length = 1L)
    )
  }

  hla_dist <- data.frame(d, stringsAsFactors = FALSE)

  return(hla_dist)
}

#' Helper function returning alignment for Grantham distance calculations
#'
#' @param gene Character vector specifying HLA gene.
#' @param resolution Number giving allele resolution.
#' @param aa_sel Numeric vector specifying amino acids that should be extracted.
#'
#' @return HLA alignment processed for grantham distance calculation. Processing 
#'   includes extracting specific amino acids, masking indels, gaps and stop 
#'   codons.
#'
hlaAlignmentGrantham <- function(gene, resolution, aa_sel = 2:182) {
  alignment <- readHlaAlignments(
    gene = gene,
    resolution = resolution,
    trim = TRUE
  )
  alignment <- alignment[, aa_sel] # select amino acids
  mask <- apply(alignment, 1, function(x) any(x == "" | x == "X" | x == ".")) # mask gaps, stop codons, indels
  alignment <- alignment[! mask, ]

  return(alignment)
}

#' Get HLA calls genes
#'
#' \code{getHlaCallsGenes} get's genes found in HLA calls.
#'
#' @inheritParams checkHlaCallsFormat
#'
#' @return Character vector of genes in \code{hla_calls}.
#'
#' @importFrom assertthat assert_that
#'
getHlaCallsGenes <- function(hla_calls) {
  assert_that(
    checkHlaCallsFormat(hla_calls)
  )

  genes <- hla_calls %>%
    colnames() %>%
    `[`(-1) %>% # discard ID column
    gsub(pattern = "_[0-9]+", replacement = "") %>%
    unique()

  return(genes)
}

#' Helper transform data frame to experiment matrix
#'
#' Function deletes 'ID' column from a \code{df}, then transpose it and sets
#' the column names to values from deleted 'ID' column.
#'
#' @param df Data frame
#'
#' @return Matrix representation of \code{df}.
#'
#' @importFrom utils type.convert
#'
dfToExperimentMat <- function(df) {
  cols <- df[["ID"]]
  mat <- t(df[, ! colnames(df) == "ID", drop = FALSE])
  colnames(mat) <- cols

  # convert to apropiate type
  # mat <- type.convert(mat, as.is = TRUE)

  return(mat)
}

#' Helper transform experiment matrix to data frame
#'
#' Function transpose \code{mat} and inserts column names of input \code{mat} as
#' a 'ID' column.
#'
#' @param mat Matrix
#'
#' @return Data frame representation of \code{mat}.
#'
experimentMatToDf <- function(mat) {
  ID <- colnames(mat)
  df <-
    as.data.frame(
      t(mat),
      stringsAsFactors = FALSE,
      make.names = FALSE
    )
  rownames(df) <- NULL
  df <- cbind(ID, df, stringsAsFactors = FALSE)

  return(df)
}

#' Transform MiDAS to wide format data.frame
#'
#' @param object Object of class MiDAS
#' @param experiment Character specifying experiments to include
#'
#' @return Data frame representation of MiDAS object. Consecutive columns holds
#'   values of variables from MiDAS's experiments and colData. The metadata
#'   associated with experiments is not preserved.
#'
#' @importFrom assertthat assert_that
#' @importFrom dplyr left_join
#' @importFrom methods is validObject
#' @importFrom magrittr %>%
#' @importFrom MultiAssayExperiment colData experiments
#' @importFrom tibble rownames_to_column
#'
midasToWide <- function(object, experiment) {
  assert_that(
    validObject(object),
    is.character(experiment),
    characterMatches(experiment, getExperiments(object))
  )

  ex_list <- experiments(object)[experiment]
  ex_list <- lapply(
    X = ex_list,
    FUN = function(x) {
      if (is(x, "SummarizedExperiment")) x <- assay(x)
      x %>%
        t() %>%
        as.data.frame(optional = TRUE) %>%
        rownames_to_column(var = "ID")
    }
  )
  col_data <- colData(object) %>%
    as.data.frame(optional = TRUE) %>%
    rownames_to_column(var = "ID")
  ex_list[[length(ex_list) + 1]] <- col_data # append
  wide_df <- Reduce(function(x, y) left_join(x, y, by = "ID"), ex_list)

  return(wide_df)
}

#' Check KIR genes format
#'
#' \code{checkKirGenesFormat} test if the input character follows KIR gene names
#' naming conventions.
#'
#' KIR genes: "KIR3DL3", "KIR2DS2", "KIR2DL2", "KIR2DL3", "KIR2DP1", "KIR2DL1",
#' "KIR3DP1", "KIR2DL1", "KIR3DP1", "KIR2DL4", "KIR3DL1", "KIR3DS1", "KIR2DL5",
#' "KIR2DS3", "KIR2DS5", "KIR2DS4", "KIR2DS1", "KIR3DL2".
#'
#' @param genes Character vector with KIR gene names.
#'
#' @return Logical vector specifying if \code{genes} elements follow KIR genes
#'   naming conventions.
#'
#' @examples
#' checkKirGenesFormat(c("KIR3DL3", "KIR2DS2", "KIR2DL2"))
#'
#' @importFrom assertthat assert_that
#' @importFrom stringi stri_detect_regex
#' @export
checkKirGenesFormat <- function(genes) {
  pattern <- "^KIR[0-9]{1}D[A-Z]{1}[0-9]{1}$"
  is_correct <- stri_detect_regex(genes, pattern)

  return(is_correct)
}

#' Iterative likelihood ratio test
#'
#' \code{iterativeLRT} performs likelihood ratio test in an iterative manner
#' over groups of variables given in \code{omnibus_groups}.
#'
#' @inheritParams updateModel
#' @inheritParams omnibusTest
#'
#' @return Data frame containing summarised likelihood ratio test results.
#'
#' @importFrom dplyr bind_rows
#'
iterativeLRT <- function(object, placeholder, omnibus_groups) {
  mod0 <- updateModel(
    object = object,
    x = "1",
    placeholder = placeholder,
    backquote = FALSE
  )
  results <- lapply_tryCatch(
    X = omnibus_groups, 
    FUN = function(x)
        LRTest(
          mod0,
          updateModel(
            object = object,
            x = x,
            placeholder = placeholder,
            collapse = " + ",
            backquote = TRUE
          )
        ), 
    err_res = function(x)
      data.frame(
        term = toString(x),
        df = NA,
        logLik = NA,
        statistic = NA,
        p.value = NA,
        stringsAsFactors = FALSE
      )
  )
  results <- bind_rows(results, .id = "group")
  
  return(results)
}

#' Iteratively evaluate model for different variables
#' 
#' Information about variable statistic from each model is extracted using 
#' \code{tidy} function.
#'
#' @inheritParams updateModel
#' @inheritParams analyzeAssociations
#'
#' @return Tibble containing per variable summarised model statistics. The exact
#'   output format is model dependent and controlled by model's dedicated 
#'   \code{tidy} function.
#'   
#' @importFrom dplyr bind_rows tibble
#' @importFrom broom tidy
#'
iterativeModel <- function(object,
                           placeholder,
                           variables,
                           exponentiate = FALSE) {
  results <- lapply_tryCatch(
    X = variables,
    FUN = function(x) {
      obj <- updateModel(
        object = object,
        x = x,
        placeholder = placeholder,
        backquote = TRUE,
        collapse = " + "
      )
      tidy(x = obj,
           conf.int = TRUE,
           exponentiate = exponentiate)
    },
    err_res = function(x) {
      failed_result <- tidy(x = object, conf.int = TRUE)[1,]
      failed_result[1,] <- NA
      failed_result$term <- x
      failed_result
    }
  )
  results <- bind_rows(results)
  
  # drop covariates
  results$term <- gsub("`", "", results$term)
  results <- results[results$term %in% variables, ]

  # add entries for variables dropped by tidy due to NA estimate
  mask <- ! variables %in% results$term
  if (any(mask)) {
    failed_results <- tibble(
      term = variables[mask],
      estimate = rep(NA, sum(mask)),
      std.error = rep(NA, sum(mask)),
      statistic = rep(NA, sum(mask)),
      p.value = rep(NA, sum(mask))
    )
    results <- bind_rows(results, failed_results)
  }

  return(results)
}

#' Helper transforming reference frequencies
#'
#' @param ref Long format data frame with three columns "var", "population",
#'   "frequency".
#' @param pop Character giving names of populations to include
#' @param carrier_frequency Logical indicating if carrier frequency should be
#'   returned instead of frequency. Carrier frequency is calculated based on
#'   Hardy-Weinberg equilibrium model.
#'
#' @return Wide format data frame with population frequencies as columns.
#'
#' @importFrom assertthat assert_that
#' @importFrom dplyr filter select
#' @importFrom rlang .data !!
#' @importFrom stats reshape
#'
getReferenceFrequencies <- function(ref, pop, carrier_frequency = FALSE) {
  assert_that(
    is.data.frame(ref),
    colnamesMatches(ref, c("var", "population", "frequency")),
    is.character(pop),
    characterMatches(pop, unique(ref$population)),
    isTRUEorFALSE(carrier_frequency)
  )

  ref <- dplyr::filter(ref, .data$population %in% pop)
  ref <- reshape(
    data = ref,
    idvar = "var",
    timevar = "population",
    direction = "wide"
  )
  colnames(ref)[-1] <-
    gsub("frequency\\.", "", colnames(ref)[-1])
  cols <- c("var", pop)
  ref <- select(ref, !!cols) # rename populations if needed

  if (carrier_frequency) {
    ref[, -1] <- lapply(ref[, -1, drop = FALSE], function (x) 2 * x * (1 - x) + x^2) # HWE 2qp + q^2
  }

  return(ref)
}

#' Adjust P-values for Multiple Comparisons
#'
#' Given a set of p-values, returns p-values adjusted using one of several
#' methods.
#'
#' This function modifies \code{stats::p.adjust} method such that for Bonferroni
#' correction it is possible to specify \code{n} lower than \code{length(p)}.
#' This feature is useful in cases when knowledge about the biology or
#' redundance of alleles reduces the need for correction.
#'
#' See \code{\link[stats]{p.adjust}} for more details.
#'
#' @inheritParams stats::p.adjust
#' @param n number of comparisons, must be at least \code{length(p)}; only set
#'   this (to non-default) when you know what you are doing! Note that for
#'   Bonferroni correction it is possible to specify number lower than
#'   \code{length(p)}.
#'
#' @return A numeric vector of corrected p-values (of the same length as p, with
#'   names copied from p).
#'
#' @importFrom assertthat assert_that is.number is.string
#' @importFrom stats p.adjust
#'
adjustPValues <- function(p, method, n = length(p)) {
  assert_that(
    assertthat::see_if(
      is.numeric(p),
      msg = sprintf("%s that is bad", as.character(p))
    ),
    is.numeric(p),
    is.string(method),
    is.number(n)
  )

  if (method == "bonferroni") {
    assert_that(
      n >= 1,
      msg = "n must be >= 1"
    )
    p_adj <- p * n
    p_adj <- ifelse(p_adj > 1, 1, p_adj)
  } else {
    p_adj <- p.adjust(p, method, n)
  }

  return(p_adj)
}

#' Filter list by elements
#'
#' Filter two level list by its secondary elements and remove empty items
#'
#' @param list A list.
#' @param elements Character vector of elements to keep.
#'
#' @return List filtered according to \code{elements} argument.
#'
#' @importFrom stats setNames
#'
filterListByElements <- function(list, elements) {
  list_names <- names(list)
  list_vec <- setNames(
    object = unlist(x = list, recursive = TRUE),
    nm = rep(x = list_names, times = vapply(X = list, FUN = length, FUN.VALUE = integer(1L)))
  )
  list_vec <- list_vec[list_vec %in% elements]
  new_list <- lapply(
    X = list_names,
    FUN = function(x) {
      vec <- list_vec[names(list_vec) == x]
      names(vec) <- NULL
      vec
    }
  )
  names(new_list) <- list_names
  new_list <- new_list[vapply(X = new_list, FUN = function(x) length(x) != 0, FUN.VALUE = logical(1L))]
  
  return(new_list)
}

#' lapply with tryCatch routine
#'
#' Used to run function iteratively over list, while using tryCatch to
#' catch warnings and errors to finally present a summary of issues rather
#' than error on each and every one. Used in \code{iterativeLRT} and
#' \code{iterativeModel}.
#'
#' @inheritParams base::lapply
#' @param err_res Function creating a result that should be output in case of 
#'   error.
#'
#' @return List of elements as returned by \code{FUN}.
#'
#'
lapply_tryCatch <- function(X, FUN, err_res, ...) {
  conditional_msgs <- environment()
  conditional_msgs$error <- character()
  conditional_msgs$warning <- character()
  
  result <- lapply(
    X = X,
    FUN = function(x) suppressWarnings(tryCatch(
      expr = FUN(x, ...),
      error = function(e) {
        err <- get(x = "error", envir = conditional_msgs)
        err <- c(err, conditionMessage(e))
        names(err)[length(err)] <- x[1] # take first variable, len(x) >= 1 
        assign(x = "error", value = err, envir = conditional_msgs)
        
        return(err_res(x))
      },
      warning = function(w) { # if there is a warning followed by an error the function will actually crash dramatically
        wrr <- get(x = "warning", envir = conditional_msgs)
        wrr <- c(wrr, conditionMessage(w))
        names(wrr)[length(wrr)] <- x[1] # take first variable, len(x) >= 1 
        assign(x = "warning", value = wrr, envir = conditional_msgs)
        
        res <- suppressWarnings(try(expr = FUN(x, ...), silent = TRUE))
        if (assertthat::is.error(res)) {
          err <- get(x = "error", envir = conditional_msgs)
          err <- c(err, toString(res))
          names(err)[length(err)] <- x[1] # take first variable, len(x) >= 1 
          assign(x = "error", value = err, envir = conditional_msgs)

          res <- err_res(x)
        }
        
        res
      }  
    ))
  )
  
  # messages in this section has been created specifically for iterativeLRT and iterativeModel  
  # communicate errors and warnings <--------------------------------------------------------------
  had_error <- length(conditional_msgs$error)
  had_warning <- length(conditional_msgs$warning)
  if (had_error || had_warning) {
    msg <- "While evaluating the model problems occured:\n"
    if (had_error) {
      msg <- c(msg, "Errors:\n")
      err <- table(conditional_msgs$error)
      for (i in seq_along(err)) {
        n <- err[i]
        val <- names(err)[i]
        vars <- conditional_msgs$error[conditional_msgs$error == val]
        vars <-
          ifelse(
            test = length(vars) <= 5,
            yes = paste(names(vars), collapse = ", "),
            no = paste(c(names(vars)[seq_len(5)], "..."), collapse = ", ")
          )
        msg <- c(
          msg,
          sprintf("%s; occured %i times, including variables: %s", val, n, vars)
        )
      }
      msg <- c(msg, "") # spacer
    }
    
    if (had_warning) {
      msg <- c(msg, "Warnings:")
      wrr <- table(conditional_msgs$warning)
      for (i in seq_along(wrr)) {
        n <- wrr[i]
        val <- names(wrr)[i]
        vars <- conditional_msgs$warning[conditional_msgs$warning == val]
        vars <-
          ifelse(
            test = length(vars) <= 5,
            yes = paste(names(vars), collapse = ", "),
            no = paste(c(names(vars)[seq_len(5)], "..."), collapse = ", ")
          )
        msg <- c(
          msg,
          sprintf("%s; occured %i times, including variables: %s", val, n, vars)
        )
      }
    }
    
    warn(msg)
  }
  
  return(result)
}
