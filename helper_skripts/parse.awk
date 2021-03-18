#!/usr/bin/awk -f

BEGIN{
    OFS = ";";
    
    # output variables
    ## edit the follwing variables
    tf_test_rep = "AKOM/sprint/1/somefolder";  # folder of test in jira testrepository
    tf_fixvers  = "1.0.0";          # version of release
    tf_author   = "gsz";            # your initials (avision)
    ## don't edit the following
    tf_jira_nr  = "";
    tf_nr       = 0 ;
    tf_desc     = "";
    tf_story_id = "";
    tf_resol    = "Fertig"
    tf_status   = "Created"
    tf_step_nr  = 1 ;
    tf_step     = "";
    tf_t_data   = "";
    tf_result   = "";

    # work varaibles
    tf_desc_s   = "";
    tf_step_s   = "";
    tf_result_s = "";
    lastline    = "";
}

{
    # getting related userstory id from FILENAME
    #n=split(orgfile,path,"/")
    split(orgfile,storyid,"_")
    tf_story_id = storyid[1]
    
    if($1 ~ "^context")
    {
        split($0,a_desc," ")
        tf_desc = a_desc[2]
        tf_jira_nr = a_desc[1]
        gsub("context..","",tf_jira_nr)
        gsub("',","",tf_desc)
        if (tf_desc == "" || tf_desc != tf_desc_s)
        {
            tf_desc_s   = tf_desc
            tf_step     = "";
            tf_step_nr  = 0 ;
            tf_nr++
        }
        lastline = "desc"
    }
    
    if($1 ~ "^it")
    {
        tf_step = substr($0,4)
        gsub("['()=>{',;]","",tf_step)
        sub(/[ \t]+$/,"",tf_step)
        gsub("/","\\/",tf_step)
        if (tf_step == "" || tf_step != tf_step_s)
        {
            tf_step_s    = tf_step
            tf_result = "OK";
            tf_step_nr++
        }
        lastline = "step"
    }

    if($0 ~ "should") 
    {
        tf_result=$0
        tf_step_nr++
        if (tf_result == "") 
        {   
            tf_result   = "OK"
            tf_result_s = tf_result
        }
        if (tf_result != tf_result_s)
        {
            tf_result_s = tf_result
        }
        lastline = "result"
    }

    if(tf_desc != "" && tf_step != "" && tf_result != "")
    {
        write_tf_line()
    }
    
}

# functions
function write_tf_line() {
    print tf_jira_nr";"tf_nr";"tf_desc";"tf_story_id";"tf_fixvers";"tf_desc";"tf_resol";"tf_author";"tf_status";"tf_step_nr";"tf_step";"tf_t_data";"tf_result
    
}




