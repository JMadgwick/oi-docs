#!/usr/bin/env bash
##############################################################################
# makepdf.sh: A simple bash script to produce pdfs for OpenIndiana Docs
#
# Copyright (C) 2017  Benny Lyons: benny.lyons@gmx.net
# CDDL HEADER START
#
# The contents of this file are subject to the terms of the
# Common Development and Distribution License (the "License").
# You may not use this file except in compliance with the License.
#
# You can obtain a copy of the license at https://illumos.org/license/
# 
# When distributing Covered Code, include this CDDL HEADER in each
# file and include the License file at https://illumos.org/license/
# If applicable, add the following below this CDDL HEADER, with the
# fields enclosed by brackets "[]" replaced with your own identifying
# information: Portions Copyright [yyyy] [name of copyright owner]
#
# CDDL HEADER END
#
#
# Contributor(s):
#

help()
{
    cat<<EOF
    Usage: $0 <options> 

    Simple script to produce pdf for OpenIndiana Docs

    Without any options, all files ending in .md in the following
    directories are converted:
        books
        contrib
        dev
        handbook
        handbook/community
        misc

    All files produced will be placed in new directory (./pdf/)

    REQUIREMENTS
    On a Debian system, you must install the following packages:
        $ sudo pip install pandoc
        $ sudo pip install mkdocs-pandoc
        $ sudo apt-get install texlive-full
        $ sudo apt-get install texlive-xetex

    OPTIONS
    -d <subdir>  convert all files in this subdirectory
    -f <filename> only convert this filename
       Default: convert everything
    -h this help
    -t <pdf || epub> output type either pdf or epub
       Default: pdf
    -s <web || opensolaris> output style either web or opensolaris (only applicable to pdf)
       Default: pdf

    EXAMPLES
    Convert all files in the contrib sub-dir:
        makepdf.sh -d contrib
    Convert getting-started.md:
        makepdf.sh -f ./docs/contrib/getting-started.md
    Produce epub:
        makepdf.sh -t epub -f ./docs/contrib/getting-started.md
EOF
}

get_file_basename ()
{
        this_file=$1
        this_file="${this_file##*/}"
        echo "${this_file%.*}"
}

get_file_ext ()
{
        this_file=$1
        echo "${this_file##*.}"
}

get_file_path()
{
        this_file=$1
        echo $(dirname "$infile")
}

#
# pandoc 2.8 was released on 2019-11-22 which is the first
# version to support LaTex in the header-includes variable
# For backward compatibility, we'd like to support older
# pandoc versions, but would prefer new features
is_pandoc_version_new()
{
        pandoc_version_match="^pandoc ([0-9]+)\.([0-9]+).*$"

        if [[ $(pandoc --version) =~ $pandoc_version_match ]]; then
            if [ "${BASH_REMATCH[1]}" -gt "2" ]; then
                echo "true"
            elif [ "${BASH_REMATCH[1]}" -eq "2" ] && [ "${BASH_REMATCH[2]}" -ge "8" ]; then
                echo "true"
            else
                echo "false"
            fi
        else
                echo "false"
        fi
}


do_conversion()
{
        input=$1
        output=$2
        format=$3
        style=$4

        if [ "$format" == "epub" ]; then
                $(pandoc -t epub --toc -f markdown+grid_tables+table_captions -o $output $input  --pdf-engine=xelatex)
        elif [ "$format" == "pdf" ]; then
                if [ "$(is_pandoc_version_new)" == "false" ]; then
                        $(pandoc --toc -f markdown+grid_tables+table_captions -o $output $input  --pdf-engine=xelatex)
                else
                        if [ "$style" == "opensolaris" ]; then
                            $(pandoc --pdf-engine=xelatex --lua-filter $OLDPWD/pandoc/filter-sb.lua --metadata-file $OLDPWD/pandoc/config-sb.yaml -o $output $input)
                        else
                            $(pandoc --pdf-engine=xelatex --lua-filter $OLDPWD/pandoc/filter-web.lua --metadata-file $OLDPWD/pandoc/config-web.yaml -o $output $input)
                        fi
                fi
        fi

}



main ()
{
        #
        # Command Line Options
        #
        while getopts "hd:f:t:s:" opt; do
	        case $opt in
                        d)
                                indir=$OPTARG
                                ;;
                        f)
                                infile=$OPTARG
                                ;;
                        h)
                                help
                                exit 0
                                ;;
                        t)
                                outformat=$OPTARG
                                ;;
                        s)
                                outstyle=$OPTARG
                                ;;
                        \?)
                                echo "Don't know this option"
                                exit 0
                                ;;
		esac
	done



        if [[ -n "$indir" && -n "$infile" ]]; then
                echo "ERROR: specify -d OR -f, but not both"
                exit 1
        fi

        if [ ! -n "$outformat" ]; then
                outformat="pdf" # Default format
        elif [ "$outformat" != "epub" ] && [ "$outformat" != "pdf" ] ; then
                echo >&2 "ERROR: -t can only be pdf or epub"
                exit 1
        fi

        if [ ! -n "$outstyle" ]; then
                outstyle="web" # Default style
        elif [ "$outstyle" != "web" ] && [ "$outstyle" != "opensolaris" ] ; then
                echo >&2 "ERROR: -s can only be web or opensolaris"
                exit 1
        fi



        # Required packages ok?
        type pandoc >/dev/null 2>&1 || {
                echo >&2 "ERROR: require package pandoc, please install pandoc."
                exit 1; }

        # Older versions of pandoc work, but we'd prefer the newer
        # features.
        # Issue a warning if an older version of pandoc is in use
        if [ "$(is_pandoc_version_new)" == "false" ]; then
                echo "WARNING: you are using an older version of pandoc"
        fi



        # -f <filename>
        # Only a single file
        if [ -n "$infile" ]; then
                # File must be present
                if [ -f "$infile" ]; then
                        this_path=$(get_file_path $infile)
                        file_basename=$(get_file_basename $infile)
                        pdf_path=$(pwd)"/pdf/"$this_path
                        mkdir -p $pdf_path
                        echo "  Writing output to this directory: " "pdf/"$this_path

                        cd $this_path
                        if [ "$outformat" == "pdf" ]; then
                                outfile_ext=$file_basename".pdf"
                        elif [ "$outformat" == "epub" ]; then
                                outfile_ext=$file_basename".epub"
                        fi

                        echo "    Generating: " $outfile_ext
                        outfile_ext=$pdf_path"/"$outfile_ext
                        this_infile=$file_basename".md"

                        $(do_conversion $this_infile $outfile_ext $outformat $outstyle)
                else
                    printf "\n"
                    echo "ERROR: cannot find file: " $infile
                    exit 1
                fi
                cd - > /dev/null
                exit 0
        fi

        
        # -d <subdirectory>
        # An entire subdirectory
        if [ -n "$indir" ]; then
                # Directory must be present
                if [ -d "$indir" ]; then
                        this_dir="$indir"
                elif [ -d "./docs/$indir" ]; then
                        this_dir="./docs/$indir"
                else
                        printf "\n"
                        echo "ERROR: cannot find directory: " $indir
                        exit 1
                fi

                pdf_path=$(pwd)"/pdf/"$indir
                mkdir -p $pdf_path
                echo "  Writing output to this directory: " "pdf/"$indir
                infiles=$(ls $this_dir)
                
                cd $this_dir
                for infile in $infiles; do
                        file_basename=$(get_file_basename $infile)

                        if [ "$outformat" == "pdf" ]; then
                                outfile_ext=$file_basename".pdf"
                        elif [ "$outformat" == "epub" ]; then
                                outfile_ext=$file_basename".epub"
                        fi
                        outfile_ext=$pdf_path"/"$outfile_ext
                        file_ext=$(get_file_ext $infile)
                        # Only process *md files
                        if [ "$file_ext" == "md" ]; then
                                echo "    Generating: " $file_basename"."$outformat
                                $(do_conversion $infile $outfile_ext $outformat $outstyle)
                        fi
                done
                cd - > /dev/null
                exit 0
        fi

        # Default: do all directories
        
        # Only these directories in docs:
        #     books - Needs HTML in markdown to be fixed
        #     contrib
        #     dev
        #     handbook
        #     handbook/community
        #     misc
        dirspath=docs
        dirs="contrib dev handbook handbook/community misc"
        for dir in $dirs; do
                this_path=$dirspath"/"$dir
                pdf_path=$(pwd)"/pdf/"$dir
                mkdir -p $pdf_path
                echo "-------------------------"
                echo "Output to this directory: " "pdf/"$dir
                these_files=$(ls $this_path)
                for this_file in $these_files; do
                        file_basename=$(get_file_basename $this_file)
                        file_ext=$(get_file_ext $this_file)

                        if [ "$outformat" == "pdf" ]; then
                                outfile_ext=$file_basename".pdf"
                        elif [ "$outformat" == "epub" ]; then
                                outfile_ext=$file_basename".epub"
                        fi

                        outfile_ext=$pdf_path"/"$outfile_ext
                        this_infile=$file_basename".md"

                        cd $this_path

                        # Only process *md files
                        if [ "$file_ext" == "md" ]; then
                                $(do_conversion $this_infile $outfile_ext $outformat $outstyle)
                                echo "    Generating: " $file_basename"."$outformat
                        fi
                        cd - > /dev/null
                done
        done
}

# Execute this script
main $@


