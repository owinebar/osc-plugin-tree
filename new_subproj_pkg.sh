#!/bin/bash

prj_name="$(< ./.osc/_project)"
prj_meta="$(osc meta prj)"
prjconf_meta="$(osc meta prjconf)"

subprj_name="$1"
subprj="${prj_name}:${subprj_name}"
pkg="${subprj_name}"
srcpkg=""
if [ $# -ge 2 ]; then
    pkg="$2"
fi
if [ $# -ge 3 ]; then
    srcpkg="$3"
fi
mkdir "${subprj_name}"
pushd "${subprj_name}" >/dev/null 2>&1
echo "$prj_meta" | sed -re "s/<project +name=\"${prj_name}\" *>/<project name=\"${subprj}\">/g" >_prj
echo "$prjconf_meta" >_prjconf
osc meta prj -F _prj "${prj_name}:${subprj_name}"
osc meta prjconf -F _prjconf "${prj_name}:${subprj_name}"
osc init "${prj_name}:${subprj_name}"
srcdesc=""
rpmsrc="Source0: ${pkg}-%{version}.tar.gz"
if [ -n "$srcpkg" ]; then
    srcdesc=" - sourced from ${srcpkg}"
    rpmsrc="%if %{build_tar_ball}
Source0: ${pkg}-%{version}.tar.gz
%else
Source0: _service
%endif
"
fi
cat >_pkg <<EOF
<package name="${pkg}" project="${subprj}">
  <title>${pkg}</title>
  <description>Package for ${pkg}</description>
</package>
EOF
osc  meta pkg -F _pkg "${subprj}" "${pkg}"
osc co ${pkg}
cd ${pkg}
cat >${pkg}.spec <<EOF
#
# spec file for ${pkg}
#
# Copyright (c) 2023 Onnie Lynn Winebarger
#
# All modifications and additions to the file contributed by third parties
# remain the property of their copyright owners, unless otherwise agreed
# upon. The license for this file, and modifications and additions to the
# file, is the same license as for the pristine package itself (unless the
# license for the pristine package is not an Open Source License, in which
# case the license is the MIT License). An "Open Source License" is a
# license that conforms to the Open Source Definition (Version 1.9)
# published by the Open Source Initiative.

Name:           ${pkg}
Version:        0.1.0 
Release:        0 
License:        MIT 
Group:          None
Summary:        ${pkg}
Url:            ${srcpkg}
${rpmsrc}
BuildRequires:  repocc
BuildRequires:  cmake 
BuildRoot:      %{_tmppath}/%{name}-%{version}-build

%description 
Unknown

%prep 
%setup -q -n %{name}-%{version}

%build 

%install 

%files 
%defattr(-,root,root,-)
%doc README LICENSE *.txt
%{_bindir}/*

%changelog 

EOF
cat >README <<EOF
Placeholder for ${pkg}
EOF
touch LICENSE
cat >LICENSE <<EOF
Copyright <YEAR> <COPYRIGHT HOLDER>

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is furnished
to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
EOF
if [ -n "$srcpkg" ]; then
# cat >_service <<EOF
# <services>
#   <service name="obs_scm">
#     <param name="url">${srcpkg}</param>
#     <param name="scm">git</param>
#   </service>

#   <service name="set_version" mode="buildtime"/>
#   <service name="tar" mode="buildtime"/>
#   <service name="recompress" mode="buildtime">
#     <param name="file">*.tar</param>
#     <param name="compression">xz</param>
#   </service>
# </services>

# EOF
    osc add "${srcpkg}"
fi

osc addremove
osc commit -m "Initial commit"
