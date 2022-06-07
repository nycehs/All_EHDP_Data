###########################################################################################-
###########################################################################################-
##
##  Pushing data to production database & updating StaticJson
##
###########################################################################################-
###########################################################################################-

#=========================================================================================#
# Setting up ----
#=========================================================================================#

#-----------------------------------------------------------------------------------------#
# Loading libraries
#-----------------------------------------------------------------------------------------#

library(tidyverse)
library(DBI)
library(dbplyr)
library(odbc)
library(lubridate)
library(fs)
library(keyring)
library(rvest)
library(httr)
library(svDialogs)

#-----------------------------------------------------------------------------------------#
# Connecting to BESP_Indicator
#-----------------------------------------------------------------------------------------#

odbc_driver <- 
    odbcListDrivers() %>% 
    pull(name) %>% 
    unique() %>% 
    str_subset("ODBC Driver") %>% 
    sort(decreasing = TRUE) %>% 
    head(1)

if (length(odbc_driver) == 0) odbc_driver <- "SQL Server"

EHDP_odbc <-
    dbConnect(
        drv = odbc(),
        driver = paste0("{", odbc_driver, "}"),
        server = "SQLIT04A",
        database = "BESP_Indicator",
        port = 1433,
        uid = "bespadmin",
        pwd = key_get("EHDP", "bespadmin")
    )

avail_data <- 
    EHDP_odbc %>% 
    tbl("avail_data") %>% 
    distinct(internal_id, Indicator) %>% 
    collect()

#-----------------------------------------------------------------------------------------#
# Updating StaticJson ----
#-----------------------------------------------------------------------------------------#

use_recent_uploads <-
    dlg_list(
        choices = c("Yes", "No"),
        preselect = "Yes",
        title = "Use recent uploads?"
    )


if (use_recent_uploads$res == "Yes") {
    
    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
    # getting recently pushed
    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
    
    push_history <- 
        EHDP_odbc %>% 
        tbl("push_history") %>% 
        filter(data_upload_date >= !!(today()-2)) %>%
        distinct(name) %>% 
        collect()
    
    recently_pushed <- 
        left_join(
            push_history,
            avail_data,
            by = c("name" = "Indicator")
        )
    
    internal_id <- recently_pushed$internal_id %>% unique() %>% sort()
    
} else if (use_recent_uploads$res == "No") {
    
    internal_id_list <-
        dlgInput(
            message = "Enter internal_ids to update",
            rstudio = FALSE
        )$res
    
    internal_id <- 
        internal_id_list %>% 
        str_split(",| ", simplify = TRUE) %>% 
        as.integer()
    
}


# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# Getting JSON from production site via DataHandler.ashx ----
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

indicator_json <- list()
internal_id_errors <- numeric()

url_root <- "https://a816-dohbesp.nyc.gov/IndicatorPublic/"

# invoke session

the_session <- session(paste0(url_root, "PublicTracking.aspx"))


# ---- loop through internal_ids ---- #

for (i in 1:length(internal_id)) {
    
    
    cat(i, "/", length(internal_id), " [", internal_id[i], "]", sep = "")
    
    
    # ---- modifying form ---- #
    
    this_form <- 
        
        tryCatch({
            
            the_session %>% 
                
                # navigate to indicator page to set session vars
                
                session_jump_to(
                    paste0(
                        url_root, "VisualizationData.aspx?",
                        "id=", internal_id[i], ",1,1,Summarize"
                    )
                ) %>% 
                
                # get form
                
                html_element("#aspnetForm") %>% 
                html_form() %>% 
                
                # change value of "hidEnv" in form element (STAGE = database query)
                
                html_form_set("ctl00$ContentPlaceHolder1$hidEnv" = "STAGE")
            
        }, error = function(e) {}
        )
    
    
    if (is.null(this_form)) {
        
        internal_id_errors[length(internal_id_errors) + 1] <- internal_id[i]
        
        cat(" <--ERROR")
        cat("\n")
        next
        
    }
    
    cat("\n")
    
    
    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
    # getting data
    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
    
    indicator_json[[i]] <- 
        
        the_session %>% 
        
        # submit form
        
        session_submit(form = this_form, submit = 1) %>% 
        
        # now invoke DataHandler.ashx and get response
        
        session_jump_to(paste0(url_root, "EPHTHandler/DataHandler.ashx?TypeImage=HideAndShowSummarize")) %>% 
        pluck("response") %>% 
        content()
    
    # save DataHandler.ashx response JSON
    
    write_lines(indicator_json[[i]], paste0("StaticJson/", internal_id[i], ".json"))
    
}


# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# Getting JSON from staging site via DataHandler.ashx ----
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

# if the page doesn't exist already on production, it will redirect to the homepage before
#   the STAGE hack can take effect. So, in order to get these indicators, we have to use
#   the staging site. The data format is the same, so it should be fine.

url_root <- "http://appbesp101/IndicatorPublic/"

# invoke session

the_session <- session(paste0(url_root, "PublicTracking.aspx"))


# ---- loop through internal_ids ---- #

for (i in 1:length(internal_id_errors)) {
    
    
    cat(i, "/", length(internal_id_errors), " [", internal_id_errors[i], "]", sep = "")
    
    
    # ---- modifying form ---- #
    
    this_form <- 
        
        tryCatch({
            
            the_session %>% 
                
                # navigate to indicator page to set session vars
                
                session_jump_to(
                    paste0(
                        url_root, "VisualizationData.aspx?",
                        "id=", internal_id_errors[i], ",1,1,Summarize"
                    )
                ) %>% 
                
                # get form
                
                html_element("#aspnetForm") %>% 
                html_form() %>% 
                
                # change value of "hidEnv" in form element (STAGE = database query)
                
                html_form_set("ctl00$ContentPlaceHolder1$hidEnv" = "STAGE")
            
        }, error = function(e) {}
        )
    
    
    if (is.null(this_form)) {
        
        cat(" <--ERROR")
        cat("\n")
        next
        
    }
    
    cat("\n")
    
    
    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
    # getting data
    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
    
    indicator_json[[length(indicator_json) + 1]] <- 
        
        the_session %>% 
        
        # submit form
        
        session_submit(form = this_form, submit = 1) %>% 
        
        # now invoke DataHandler.ashx and get response
        
        session_jump_to(paste0(url_root, "EPHTHandler/DataHandler.ashx?TypeImage=HideAndShowSummarize")) %>% 
        pluck("response") %>% 
        content()
    
    # save DataHandler.ashx response JSON
    
    write_lines(indicator_json[[length(indicator_json) + 1]], paste0("StaticJson/", internal_id_errors[i], ".json"))
    
}


# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# #
# #                             ---- THIS IS THE END! ----
# #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
