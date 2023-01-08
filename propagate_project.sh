#!/bin/bash

prj_name="$(< ./.osc/_project)"
prj_meta="$(osc meta prj)"
prjconf_meta="$(osc meta prjconf)"
subprj_name="$1"
subprj="${prj_name}:${subprj_name}"
srcprj=""
srcpkg="${subprj_name}"
shift
if [ $# -ge 1 ]; then
    srcprj="$1"
    shift
fi
if [ $# -ge 1 ]; then
    srcpkg="$1"
    shift
fi
dstpkg="$srcpkg"
if [ $# -ge 1 ]; then
    dstpkg="$1"
    shift
fi

mkdir "${subprj_name}" >/dev/null 2>&1
pushd "${subprj_name}" >/dev/null 2>&1
proj_title="${subprj_name}"
echo -n "Project for ${subprj_name} packages" > _proj_desc
base_srcprj=""
dst_repos=""
conf_xpath="//person|//build|//publish|//debuginfo|//useforbuild|//accesss|//sourceaccess|//repository"
conf_src="${prj_name}"
conf_pkg=""
if [ -n "$srcprj" ]; then
    base_srcprj="$(echo -n ${srcprj} | sed -re 's/[^:]+://g' )"
    proj_title="${subprj_name} - ${dstpkg}"
    cat >_proj_desc <<EOF
Project for package ${subprj_name}/${dstpkg} derived from ${srcprj}/${srcpkg}
$(osc meta pkg "${srcprj}" "${srcpkg}" | xml sel -t -v "//description" --nl)
EOF
    # if deriving from another package in this project collection, assume we want to use any customized repos set up from the source
    # for external sources, we set the initial repos from the base project
    # And the same for the project configuration
    if [ "${srcprj}" = "${prj_name}:${base_srcprj}" ]; then
	conf_src="${srcprj}"
	conf_pkg="${srcpkg}"
    fi
fi
xml_pp -l >_prj <<EOF
<project name="${subprj}">
  <title>${proj_title}</title>
  <description>$(< _proj_desc)</description>
  $(osc meta prj ${conf_src} | xml sel -t -m "${conf_xpath}" -c "." --nl)
</project>
EOF
osc meta prjconf ${conf_src} >_prjconf
echo "Creating project ${subprj}"
osc meta prj -F _prj "${subprj}"
osc meta prjconf -F _prjconf "${subprj}"
echo "Initializing project ${subprj} directory"
osc init "${subprj}"
if [ -z "$srcprj" ]; then
    # We are done
    exit 0
fi
echo "Linking ${subprj}/${dstpkg} to ${srcprj}/${srcpkg}"
osc linkpac "$srcprj" "$srcpkg" "${subprj}" "${dstpkg}" || exit 1
osc co "$dstpkg"
cd "$dstpkg" >/dev/null 2>&1
echo "Configuring metadata for ${subprj}/${dstpkg}"
osc meta pkg "${srcprj}" "${srcpkg}" | xml sel -t -v "//description" >_pkg_desc
echo "" >_pkg_conf
if [ -n "$conf_pkg" ]; then
     osc meta pkg ${conf_src} ${conf_pkg} | xml sel -t -m "${conf_xpath}" -c "." --nl >_pkg_conf
fi
xml_pp -l  >_pkg <<EOF
<package name="${dstpkg}" project="${subprj}">
  <title>${dstpkg}</title>
  <description>$(< _pkg_desc)</description>
  $(< _pkg_conf)
</package>
EOF
osc meta pkg -F _pkg

while [ $# -ge 1 ]; do
    src_url="$1"
    echo "Adding source $src_url"
    shift
    osc add "$src_url"
done

if [ -e ./pre_checkin.sh ]; then
    echo "Running pre_checkin.sh for ${subprj}/${dstpkg}"
    sh ./pre_checkin.sh
    osc addremove
    osc commit -m "Initial commit after pre-checkin"
fi

