library(dplyr)
library(tidyr)
library(stringr)
library(openxlsx)


# Read in results
setwd("/bigdata/Jessin/Sequencing_projects/andreas/EURL_PH_AMR_SimEx_2025/kres-pipeline/")
#table_kres <- read.csv("kres/table.csv", sep = ",")
#table_kres$RID <- as.character(table_kres$RID)
#table_euro <- read.csv("eurofins/table.csv", sep = ",")
#table_euro$RID <- as.character(table_euro$RID)
table <- read.csv("table.csv", sep=",")


# Merge tables
#table_all <- bind_rows(table_kres, table_euro)

# AMRFinder results
## Create wide table
amrfinder <- table %>%
  select(RID,17:ncol(table)) %>%
  pivot_longer(
    cols = 2:ncol(.),
    names_to = "AMR_class",
    values_to = "AMR_genes"
  ) %>%
  filter(!AMR_genes == "-") %>%
  separate_rows(AMR_genes, sep = "\\|") %>%
  mutate(AMR_genes = gsub("^ ", "", AMR_genes)) %>%
  mutate(gene_name = str_extract(AMR_genes, "^[^ ]+")) %>%
  mutate(BLA = "NULL") %>%
  mutate(BLA = str_extract(gene_name, "^bla[A-Z]+")) %>%
  mutate(class = ifelse(!is.na(BLA), BLA, gene_name)) %>%
  select(-c(BLA, gene_name)) %>%
  arrange(AMR_class, RID, class) %>%
  group_by(RID, class) %>%
  summarise(AMR_genes = paste(AMR_genes, collapse = " | "), .groups = "drop") %>%
  pivot_wider(names_from = class, values_from = AMR_genes)

## Get class order
amr_class_order <- table %>%
  select(RID, 17:ncol(table)) %>%
  pivot_longer(
    cols = 2:ncol(.),
    names_to = "AMR_class",
    values_to = "AMR_genes"
  ) %>%
  filter(!AMR_genes == "-") %>%
  separate_rows(AMR_genes, sep = "\\|") %>%
  mutate(AMR_genes = str_trim(AMR_genes)) %>%
  mutate(gene_name = str_extract(AMR_genes, "^[^ ]+")) %>%
  mutate(BLA = str_extract(gene_name, "^bla[A-Z]+")) %>%
  mutate(class = ifelse(!is.na(BLA), BLA, gene_name)) %>%
  distinct(class, AMR_class) %>%
  rename(column_name = class) %>%
  rename(header = AMR_class)

amr_ordered_cols <- amr_class_order %>%
  distinct(column_name, header) %>%
  arrange(header) %>%
  pull(column_name)

amrfinder_ordered <- amrfinder %>%
  select(RID, all_of(amr_ordered_cols[amr_ordered_cols %in% colnames(.)]))



# PlasmidFinder results
plasmids <- table %>%
  select(RID, Plasmids) %>%
  separate_rows(Plasmids, sep = "\\|") %>%
  filter(!Plasmids == "-") %>%
  mutate(Plasmids = gsub("^ ", "", Plasmids)) %>%
  mutate(Plasmid_type = str_extract(Plasmids, "^[^ ]+")) %>%
  pivot_wider(names_from = Plasmid_type, values_from = Plasmids)

plasmids_class_order <- table %>%
  select(RID, Plasmids) %>%
  separate_rows(Plasmids, sep = "\\|") %>%
  filter(!Plasmids == "-") %>%
  mutate(Plasmids = gsub("^ ", "", Plasmids)) %>%
  mutate(Plasmid_type = str_extract(Plasmids, "^[^ ]+")) %>%
  mutate(header = "Plasmid replicons") %>%
  distinct(Plasmid_type, header) %>%
  rename(column_name = Plasmid_type)

plasmid_ordered_cols <- plasmids_class_order %>%
  distinct(column_name, header) %>%
  arrange(header) %>%
  pull(column_name)

plasmids_ordered <- plasmids %>%
  select(RID, all_of(plasmid_ordered_cols[plasmid_ordered_cols %in% colnames(.)]))


# Kleborate results
kleborate <- table %>%
  select(RID, OMP.mutations,) %>%
  separate_rows(OMP.mutations, sep = "\\;") %>%
  mutate(OMP_mutations_num = str_extract(OMP.mutations, "OmpK(\\d+)")) %>%
  filter(!OMP_mutations_num == "NA") %>%
  pivot_wider(names_from = OMP_mutations_num, values_from = OMP.mutations)
  

kleborate_class_order <- table %>%
  select(RID, OMP.mutations) %>%
  separate_rows(OMP.mutations, sep = "\\;") %>%
  mutate(OMP_mutations_num = str_extract(OMP.mutations, "OmpK(\\d+)")) %>%
  mutate(header = "Kleborate") %>%
  filter(!OMP_mutations_num == "NA") %>%
  distinct(OMP_mutations_num, header) %>%
  rename(column_name = OMP_mutations_num)

kleborate_ordered_cols <- kleborate_class_order %>%
  distinct(column_name, header) %>%
  arrange(header) %>%
  pull(column_name)

kleborate_ordered <- kleborate %>%
  select(RID, all_of(kleborate_ordered_cols[kleborate_ordered_cols %in% colnames(.)]))



# Remove plasmid, kleborate and amr genes
table_assembly_typing <- table %>%
  select(-c(OMP.mutations:ncol(table)))

headers_assembly_typing = c("Platform", "MLST", "MLST", "rMLST", "rMLST", "Kleborate species", "Assembly statistics", "Assembly statistics", "Assembly statistics", "Assembly statistics")
assembly_typing_class_order <- data.frame(column_name = colnames(table_assembly_typing)) %>%
  filter(!column_name == "RID") %>%
  mutate(header = headers_assembly_typing)
  






test <- table_assembly_typing %>%
  left_join(kleborate_ordered, by = "RID") %>%
  left_join(plasmids_ordered, by = "RID") %>%
  left_join(amrfinder_ordered, by = "RID")


# Bind rows of column mapping table
master_mapping <- bind_rows(assembly_typing_class_order, kleborate_class_order, plasmids_class_order, amr_class_order)



# Create excel sheet
gene_cols <- names(test)[-1]
header_map <- master_mapping %>% filter(column_name %in% gene_cols) %>%
  slice(match(gene_cols, column_name))

# Create workbook and worksheet
wb <- createWorkbook()
addWorksheet(wb, "AMR Results")

# Prepare top and bottom headers
top_header <- c("RID", header_map$header)
bottom_header <- c("RID", gene_cols)

# Write headers (transpose to write as columns)
writeData(wb, 1, t(top_header), startRow = 1, colNames = FALSE)
writeData(wb, 1, t(bottom_header), startRow = 2, colNames = FALSE)


# Write data starting from row 3
writeData(wb, 1, test, startRow = 3, colNames = FALSE)

# Merge cells for AMR_class headers spanning their columns
start_col <- 2
for (column_name in unique(header_map$header)) {
  idx <- which(header_map$header == column_name)
  if (length(idx) > 1) {
    mergeCells(wb, 1, cols = start_col + idx - 1, rows = 1)
  }
}

# Style: alternating fill colors for AMR_class header
fill_colors <- c("#E0E0E0", "#A6A6A6")
unique_classes <- unique(header_map$header)
for (i in seq_along(unique_classes)) {
  cls <- unique_classes[i]
  idx <- which(header_map$header == cls)
  cols_to_style <- start_col + idx - 1
  style_top <- createStyle(
    fgFill = fill_colors[(i %% 2) + 1],
    halign = "center", textDecoration = "bold", valign = "center"
  )
  addStyle(wb, 1, style_top, rows = 1, cols = cols_to_style, gridExpand = TRUE)
}

# Style bottom header gene names bold
bottom_header_style <- createStyle(
  textDecoration = "bold", halign = "center", valign = "center"
)
addStyle(wb, 1, bottom_header_style, rows = 2, cols = 1:(ncol(test)), gridExpand = TRUE)

# Style RID separately in both headers bold and center
rid_style <- createStyle(textDecoration = "bold", halign = "center", valign = "center")
addStyle(wb, 1, rid_style, rows = 1:2, cols = 1)

# Adjust row height for top header
setRowHeights(wb, 1, rows = 1, heights = 30)

# Auto adjust column widths
setColWidths(wb, 1, cols = 1:ncol(test), widths = "auto")


# Save workbook
saveWorkbook(wb, "amr_merged_hierarchical.xlsx", overwrite = TRUE)
