![](https://raw.github.com/jole78/wdp/master/logo.png) Web Deploy PowerShell
===

**Web Deploy PowerShell (wdp)** is a set of low ceremony, convention over configuration, PowerShell modules that wraps, and internally uses, the [Web Deploy PowerShell Cmdlets](http://www.iis.net/learn/publish/using-web-deploy/web-deploy-powershell-cmdlets).


WDP is meant to be easy (ICI Import-Customize-Invoke)...but still highly customizable if you need it to be: 
```powershell

# 1. Import
Import-Module .\WDP.Deploy.psm1


# 2. Customize (optional)
Set-Properties @{
    ParametersFile = ".\test.xample.com.xml"
}

# 3. Invoke
Invoke-Deploy .\xample.zip
```

You can read more and get the details in the [wiki section.](https://github.com/jole78/wdp/wiki)
