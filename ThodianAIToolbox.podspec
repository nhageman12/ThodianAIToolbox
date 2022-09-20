#
# Be sure to run `pod lib lint ThodianAIToolbox.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'ThodianAIToolbox'
  s.version          = '0.1.0'
  s.summary          = 'My port of AIToolbox for Swift by Kevin Cobble'


  s.description      = <<-DESC
A toolbox of AI modules written in Swift: Graphs/Trees, Linear Regression, Support Vector Machines, Neural Networks, PCA, K-Means, Genetic Algorithms, MDP, Mixture of Gaussians, Logistic Regression.This framework uses the Accelerate library to speed up computations, except the Linux package versions. Written for Swift 3.0. Earlier versions are Swift 2.2 compatible. SVM ported from the public domain LIBSVM repository See https://www.csie.ntu.edu.tw/~cjlin/libsvm/ for more information. The Metal Neural Network uses the Metal framework for a Neural Network using the GPU. While it works in preliminary testing, more work could be done with this class. Use the XCTest files for examples on how to use the classes. Playgrounds for Linear Regression, SVM, and Neural Networks are available. Now available in both macOS and iOS versions. New - Convolution Program For the Deep Network classes, please look at the Convolution project that uses the AIToolbox library to do image recognition.
                       DESC

  s.homepage         = 'https://github.com/nhageman12/ThodianAIToolbox'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'nhageman12' => 'drhageman@hotmail.com' }
  s.source           = { :git => 'https://github.com/nhageman12/ThodianAIToolbox.git', :tag => s.version.to_s }
  s.static_framework = true  

  s.platform = :osx, '12.3'
  s.swift_version = '5.0'
  s.osx.deployment_target = '12.3'
  s.frameworks = 'Foundation'
  s.module_name = 'ThodianAIToolbox'

  s.source_files = 'ThodianAIToolbox/Classes/*.swift', 'ThodianAIToolbox/Classes/*.metal', 'ThodianAIToolbox/Classes/*.h'
  
  #s.public_header_files = 'ThodianAIToolbox/Header/*.h'
  
end
