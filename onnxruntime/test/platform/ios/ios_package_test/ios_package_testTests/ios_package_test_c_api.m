// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.
//
//  ios_package_test_c_api.m
//  ios_package_testTests
//
//  This file hosts the tests of ORT C API, for tests of ORT C++ API, please see ios_package_test_cpp_api.mm
//

#import <XCTest/XCTest.h>
#include <math.h>
#include <onnxruntime/onnxruntime_c_api.h>

#define ASSERT_ON_ERROR(expr)                                                            \
  do {                                                                                   \
    OrtStatus* status = (expr);                                                          \
    XCTAssertEqual(NULL, status,                                                         \
                   @"Failed with error message: %@", @(g_ort->GetErrorMessage(status))); \
  } while (0);

@interface ios_package_test_c_api : XCTestCase {
  const OrtApi* g_ort;
}

@end

@implementation ios_package_test_c_api

- (void)setUp {
  // Put setup code here. This method is called before the invocation of each test method in the class.
  g_ort = OrtGetApiBase()->GetApi(ORT_API_VERSION);
}

- (void)tearDown {
  // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testCAPI {
  // This is an e2e test for ORT C API
  OrtEnv* env = NULL;
  ASSERT_ON_ERROR(g_ort->CreateEnv(ORT_LOGGING_LEVEL_WARNING, "testCAPI", &env));

  // initialize session options if needed
  OrtSessionOptions* so;
  ASSERT_ON_ERROR(g_ort->CreateSessionOptions(&so));
  ASSERT_ON_ERROR(g_ort->SetIntraOpNumThreads(so, 1));

  OrtSession* session;
  NSString* path = [[NSBundle mainBundle] pathForResource:@"sigmoid" ofType:@"ort"];
  const char* cPath = [path cStringUsingEncoding:NSUTF8StringEncoding];
  ASSERT_ON_ERROR(g_ort->CreateSession(env, cPath, so, &session));

  size_t input_tensor_size = 3 * 4 * 5;
  float input_tensor_values[input_tensor_size];
  float expected_output_values[input_tensor_size];
  const char* input_node_names[] = {"x"};
  const char* output_node_names[] = {"y"};
  const int64_t input_node_dims[] = {3, 4, 5};

  for (size_t i = 0; i < input_tensor_size; i++) {
    input_tensor_values[i] = (float)i - 30;
    expected_output_values[i] = 1.0f / (1 + exp(-input_tensor_values[i]));
  }

  OrtMemoryInfo* memory_info;
  ASSERT_ON_ERROR(g_ort->CreateCpuMemoryInfo(OrtArenaAllocator, OrtMemTypeDefault, &memory_info));
  OrtValue* input_tensor = NULL;
  ASSERT_ON_ERROR(g_ort->CreateTensorWithDataAsOrtValue(
      memory_info, input_tensor_values, input_tensor_size * sizeof(float),
      input_node_dims, 3, ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT, &input_tensor));
  int is_tensor;
  ASSERT_ON_ERROR(g_ort->IsTensor(input_tensor, &is_tensor));
  XCTAssertNotEqual(is_tensor, 0);
  g_ort->ReleaseMemoryInfo(memory_info);

  OrtValue* output_tensor = NULL;
  ASSERT_ON_ERROR(g_ort->Run(session, NULL, input_node_names,
                             (const OrtValue* const*)&input_tensor, 1,
                             output_node_names, 1, &output_tensor));
  ASSERT_ON_ERROR(g_ort->IsTensor(output_tensor, &is_tensor));
  XCTAssertNotEqual(is_tensor, 0);

  // Get pointer to output tensor float values
  float* output_values;
  ASSERT_ON_ERROR(g_ort->GetTensorMutableData(output_tensor, (void**)&output_values));

  for (size_t i = 0; i < input_tensor_size; i++) {
    NSLog(@"%1.10f\t%1.10f", expected_output_values[i], output_values[i]);
    XCTAssertEqualWithAccuracy(expected_output_values[i], output_values[i], 1e-6);
  }

  g_ort->ReleaseValue(output_tensor);
  g_ort->ReleaseValue(input_tensor);
  g_ort->ReleaseSession(session);
  g_ort->ReleaseSessionOptions(so);
  g_ort->ReleaseEnv(env);
}

@end
