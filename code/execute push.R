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


#=========================================================================================#
# Push and update ----
#=========================================================================================#

#-----------------------------------------------------------------------------------------#
# Executing push
#-----------------------------------------------------------------------------------------#

ret <- EHDP_odbc %>% dbExecute("EXECUTE dbo.migrate_stag_to_prod_push_ready")
print(ret)


#-----------------------------------------------------------------------------------------#
# Updating StaticJson ----
#-----------------------------------------------------------------------------------------#

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# getting recently pushed ----
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

avail_data <- 
    EHDP_odbc %>% 
    tbl("avail_data") %>% 
    distinct(internal_id, Indicator) %>% 
    collect()

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


# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# Getting JSON from site via DataHandler.ashx ----
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

indicator_json <- list()

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


# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# #
# #                             ---- THIS IS THE END! ----
# #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
