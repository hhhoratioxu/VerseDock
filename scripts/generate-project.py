#!/usr/bin/env python3
"""Generate a deterministic native Xcode project without external generators."""
import hashlib
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
objects = {}

def uid(value):
    return hashlib.sha256(value.encode()).hexdigest()[:24].upper()

def quote(value):
    return '"' + str(value).replace('\\', '\\\\').replace('"', '\\"') + '"'

def render(value):
    if isinstance(value, dict):
        return '{ ' + ' '.join(f'{quote(k)} = {render(v)};' for k, v in value.items()) + ' }'
    if isinstance(value, list):
        return '( ' + ', '.join(render(v) for v in value) + ' )'
    return quote(value)

def add(label, **values):
    identifier = uid(label)
    objects[identifier] = values
    return identifier

def configurations(name, settings):
    refs = []
    for mode in ('Debug', 'Release'):
        values = {**settings, 'SWIFT_OPTIMIZATION_LEVEL': '-Onone' if mode == 'Debug' else '-O'}
        if mode == 'Debug': values['SWIFT_ACTIVE_COMPILATION_CONDITIONS'] = 'DEBUG'
        refs.append(add(f'{name}:{mode}', isa='XCBuildConfiguration', name=mode, buildSettings=values))
    return add(f'{name}:configurations', isa='XCConfigurationList', buildConfigurations=refs,
               defaultConfigurationIsVisible='0', defaultConfigurationName='Release')

all_files = sorted(str(p.relative_to(ROOT)) for directory in ('Sources', 'App', 'Config')
                   for p in (ROOT / directory).rglob('*')
                   if (p.is_file() or p.suffix == '.xcassets')
                   and p.name != '.DS_Store'
                   and not any(parent.suffix == '.xcassets' for parent in p.parents))
references = {}
for path in all_files:
    kind = 'sourcecode.swift' if path.endswith('.swift') else (
        'folder.assetcatalog' if path.endswith('.xcassets') else (
        'image.icns' if path.endswith('.icns') else ('image.png' if path.endswith('.png') else 'text.plist.xml')))
    references[path] = add('file:' + path, isa='PBXFileReference', lastKnownFileType=kind,
                           path=path, sourceTree='<group>')

products = {}
for name, extension, kind in [('VerseCore', 'a', 'archive.ar'), ('VerseDockMac', 'app', 'wrapper.application'),
                              ('VerseDock', 'app', 'wrapper.application'), ('VerseDockActivity', 'appex', 'wrapper.app-extension')]:
    filename = ('lib' if extension == 'a' else '') + name + '.' + extension
    products[name] = add('product:' + name, isa='PBXFileReference', explicitFileType=kind,
                         path=filename, sourceTree='BUILT_PRODUCTS_DIR', includeInIndex='0')

product_group = add('products', isa='PBXGroup', children=list(products.values()), name='Products', sourceTree='<group>')
main_group = add('main', isa='PBXGroup', children=list(references.values()) + [product_group], sourceTree='<group>')

project_id = uid('project')
targets = {name: uid('target:' + name) for name in products}

def dependency(name, target):
    proxy = add(name + ':proxy', isa='PBXContainerItemProxy', containerPortal=project_id, proxyType='1',
                remoteGlobalIDString=targets[target], remoteInfo=target)
    return add(name + ':dep', isa='PBXTargetDependency', target=targets[target], targetProxy=proxy)

common = {'SWIFT_VERSION': '5.0', 'CLANG_ENABLE_MODULES': 'YES', 'CODE_SIGN_STYLE': 'Automatic',
          'MACOSX_DEPLOYMENT_TARGET': '14.0', 'IPHONEOS_DEPLOYMENT_TARGET': '17.0',
          'MARKETING_VERSION': '0.1.3', 'CURRENT_PROJECT_VERSION': '4'}
core = [p for p in all_files if p.startswith('Sources/') and p.endswith('.swift')]
shared = [p for p in all_files if p.startswith('App/Shared/') and p.endswith('.swift')]
mac = [p for p in all_files if p.startswith('App/macOS/') and p.endswith('.swift')]
ios = [p for p in all_files if p.startswith('App/iOS/') and p.endswith('.swift')]
widget = [p for p in all_files if p.startswith('App/LiveActivity/') and p.endswith('.swift')]
specifications = {
 'VerseCore': (core, {'PRODUCT_NAME': 'VerseCore', 'PRODUCT_MODULE_NAME': 'VerseCore', 'DEFINES_MODULE': 'YES',
                     'SKIP_INSTALL': 'YES', 'SUPPORTED_PLATFORMS': 'macosx iphoneos iphonesimulator',
                     'SDKROOT': 'auto'}, 'com.apple.product-type.library.static'),
 'VerseDockMac': (shared + mac, {'PRODUCT_NAME': 'VerseDockMac', 'PRODUCT_BUNDLE_IDENTIFIER': 'com.horatio.versedock.mac',
                     'INFOPLIST_FILE': 'Config/Mac-Info.plist', 'CODE_SIGN_ENTITLEMENTS': 'Config/Mac.entitlements',
                     'ENABLE_HARDENED_RUNTIME': 'YES', 'SDKROOT': 'macosx', 'SUPPORTED_PLATFORMS': 'macosx'},
                     'com.apple.product-type.application'),
 'VerseDock': (shared + ios + ['App/LiveActivity/LyricsActivityAttributes.swift'], {
                     'PRODUCT_NAME': 'VerseDock', 'PRODUCT_BUNDLE_IDENTIFIER': 'com.horatio.versedock',
                     'INFOPLIST_FILE': 'Config/iOS-Info.plist', 'CODE_SIGN_ENTITLEMENTS': 'Config/iOS.entitlements',
                     'APNS_ENVIRONMENT': 'development', 'SDKROOT': 'iphoneos', 'TARGETED_DEVICE_FAMILY': '1,2',
                     'ASSETCATALOG_COMPILER_APPICON_NAME': 'AppIcon',
                     'ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS': 'NO',
                     'SUPPORTED_PLATFORMS': 'iphoneos iphonesimulator',
                     'LD_RUNPATH_SEARCH_PATHS': '$(inherited) @executable_path/Frameworks'}, 'com.apple.product-type.application'),
 'VerseDockActivity': (widget, {'PRODUCT_NAME': 'VerseDockActivity', 'PRODUCT_BUNDLE_IDENTIFIER': 'com.horatio.versedock.activity',
                     'INFOPLIST_FILE': 'Config/Widget-Info.plist', 'SDKROOT': 'iphoneos', 'TARGETED_DEVICE_FAMILY': '1,2',
                     'SUPPORTED_PLATFORMS': 'iphoneos iphonesimulator', 'SKIP_INSTALL': 'YES',
                     'APPLICATION_EXTENSION_API_ONLY': 'YES',
                     'LD_RUNPATH_SEARCH_PATHS': '$(inherited) @executable_path/Frameworks @executable_path/../../Frameworks'},
                     'com.apple.product-type.app-extension')
}

for name, (files, settings, product_type) in specifications.items():
    build_files = [add(name + ':build:' + p, isa='PBXBuildFile', fileRef=references[p]) for p in files]
    sources = add(name + ':sources', isa='PBXSourcesBuildPhase', buildActionMask='2147483647', files=build_files, runOnlyForDeploymentPostprocessing='0')
    linked = []
    deps = []
    if name in ('VerseDockMac', 'VerseDock'):
        linked.append(add(name + ':linkCore', isa='PBXBuildFile', fileRef=products['VerseCore']))
        deps.append(dependency(name + ':core', 'VerseCore'))
    frameworks = add(name + ':frameworks', isa='PBXFrameworksBuildPhase', buildActionMask='2147483647', files=linked, runOnlyForDeploymentPostprocessing='0')
    phases = [sources, frameworks]
    resources = (['App/Resources/Assets.xcassets'] if name == 'VerseDock' else (
                 ['App/Resources/AppIcon.icns', 'App/Resources/BrandMark.png'] if name == 'VerseDockMac' else []))
    if resources:
        resource_files = [add(name + ':resource:' + p, isa='PBXBuildFile', fileRef=references[p]) for p in resources]
        phases.append(add(name + ':resources', isa='PBXResourcesBuildPhase', buildActionMask='2147483647',
                          files=resource_files, runOnlyForDeploymentPostprocessing='0'))
    if name == 'VerseDock':
        deps.append(dependency(name + ':widget', 'VerseDockActivity'))
        embedded = add('embedWidget', isa='PBXBuildFile', fileRef=products['VerseDockActivity'], settings={'ATTRIBUTES': ['RemoveHeadersOnCopy']})
        phases.append(add('embedPhase', isa='PBXCopyFilesBuildPhase', buildActionMask='2147483647', dstPath='', dstSubfolderSpec='13',
                          files=[embedded], name='Embed App Extensions', runOnlyForDeploymentPostprocessing='0'))
    objects[targets[name]] = dict(isa='PBXNativeTarget', name=name, productName=name, productReference=products[name],
        productType=product_type, buildConfigurationList=configurations(name, {**common, **settings}), buildPhases=phases,
        buildRules=[], dependencies=deps)

objects[project_id] = dict(isa='PBXProject', attributes={'LastUpgradeCheck': '2700'},
    buildConfigurationList=configurations('project', common), compatibilityVersion='Xcode 14.0', developmentRegion='zh-Hans',
    hasScannedForEncodings='0', knownRegions=['zh-Hans', 'en', 'Base'], mainGroup=main_group,
    productRefGroup=product_group, projectDirPath='', projectRoot='', targets=list(targets.values()))

project = ROOT / 'VerseDock.xcodeproj'
project.mkdir(exist_ok=True)
payload = {'archiveVersion': '1', 'classes': {}, 'objectVersion': '56', 'objects': objects, 'rootObject': project_id}
(project / 'project.pbxproj').write_text('// !$*UTF8*$!\n' + render(payload) + '\n')
schemes = project / 'xcshareddata' / 'xcschemes'
schemes.mkdir(parents=True, exist_ok=True)
for name in ('VerseDockMac', 'VerseDock'):
    product = name + '.app'
    ref = f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{targets[name]}" BuildableName="{product}" BlueprintName="{name}" ReferencedContainer="container:VerseDock.xcodeproj"/>'
    (schemes / (name + '.xcscheme')).write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2700" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{ref}</BuildActionEntry></BuildActionEntries></BuildAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{ref}</BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{ref}</BuildableProductRunnable></ProfileAction>
<AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>''')
print(project)
