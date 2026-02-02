#--------------------------------------------------------------------------------
# setup.R         Setup project
#--------------------------------------------------------------------------------

# 1. set computer --------------------------------------------------------------
user <- "david" 
#user  <- "leia" 
#user  <- "jazel" 
#user  <- "alejandro" 
#user  <- "diego" 
#user  <- "paola" 
#user  <- "ignacio" 


# 2. Set main data paths -------------------------------------------------------
if(user == "david") main_dir <- "C:/Users/david/SML Dropbox/gitdata/REDUCE_review"
#if(user == "leia") main_dir <- "C:/Users/"
#if(user == "jazel") main_dir <- "C:/Users/"
#...ADD YOURS...

# set main working directory
setwd(main_dir)


# 3. Create data paths --------------------------------------------------------- 
input_data <- paste(main_dir, "input", sep="/")
if (!dir.exists(input_data)) dir.create(input_data, recursive = TRUE)

temp_data <- paste(main_dir, "temp", sep="/")
if (!dir.exists(temp_data)) dir.create(temp_data, recursive = TRUE)

output_data <- paste(main_dir, "output", sep="/")
if (!dir.exists(output_data)) dir.create(output_data, recursive = TRUE)
