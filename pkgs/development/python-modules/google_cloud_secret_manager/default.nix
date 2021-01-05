{ lib
, buildPythonPackage
, fetchPypi
, google_api_core
, grpc_google_iam_v1
, libcst
, mock
, proto-plus
, pytestCheckHook
, pytest-asyncio
}:

buildPythonPackage rec {
  pname = "google-cloud-secret-manager";
  version = "2.1.0";

  src = fetchPypi {
    inherit pname version;
    sha256 = "0c2w8ny3n84faq1mq86f16lzqgqbk1977q2f5qxn5a5ccj8v821g";
  };

  propagatedBuildInputs = [
    google_api_core
    grpc_google_iam_v1
    libcst
    proto-plus
  ];

  checkInputs = [
    mock
    pytestCheckHook
    pytest-asyncio
  ];

  pythonImportsCheck = [
    "google.cloud.secretmanager"
    "google.cloud.secretmanager_v1"
    "google.cloud.secretmanager_v1beta1"
  ];

  meta = with lib; {
    description = "Secret Manager API API client library";
    homepage = "https://github.com/googleapis/python-secret-manager";
    license = licenses.asl20;
    maintainers = with maintainers; [ siriobalmelli SuperSandro2000 ];
  };
}
