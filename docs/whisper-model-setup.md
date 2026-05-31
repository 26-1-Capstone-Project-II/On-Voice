# Whisper CoreML 모델 적용 가이드 (Git LFS)

이 문서는 On-Voice 앱의 **온디바이스 음성인식 모델**을 로컬 환경에 정상적으로 적용하기 위한 설정 방법을 정의합니다. 
새로 합류한 팀원이나, "내 로컬은 되는데 다른 환경에서는 음성인식이 안 된다"는 상황을 겪을 때 이 문서를 따르면 됩니다.

## 배경

이 앱은 fine-tuned **Whisper-tiny CoreML 모델**을 `frontend/OnVoice/Whisper_CoreML_Model/` 폴더에 넣어두고, 
그 안의 3개 `.mlmodelc`(`AudioEncoder` / `TextDecoder` / `MelSpectrogram`)를 WhisperKit으로 온디바이스 로드해 발음 전사에 사용합니다.

- 모델 로드 코드: `frontend/OnVoice/Service/WhisperPhoneticTranscriptionService.swift`
- 모델 폴더: `frontend/OnVoice/Whisper_CoreML_Model/` (약 73MB)

모델 가중치는 용량이 커서 **Git LFS**로 관리됩니다(`.gitattributes` 참고).
LFS를 설정하지 않고 클론하면 모델 파일이 실제 바이너리가 아니라 **130바이트 포인터 텍스트**로만 받아지고, 이 경우 빌드는 되지만 **앱 실행 시 모델 로드에 실패**합니다.

```
# .gitattributes 에서 LFS로 추적되는 대상
frontend/OnVoice/Whisper_CoreML_Model/**/weights/*    filter=lfs ...
frontend/OnVoice/Whisper_CoreML_Model/**/coremldata.bin filter=lfs ...
frontend/OnVoice/Whisper_CoreML_Model/**/model.mil      filter=lfs ...
```

## 1. Git LFS 설치

```bash
# macOS (Homebrew)
brew install git-lfs

# 설치 확인
git lfs version
```

## 2. LFS 활성화 (계정당 1회)

```bash
git lfs install
```

## 3. 모델 파일 받기

### 이미 클론한 경우 (대부분 여기 해당)

프로젝트 루트에서:

```bash
git lfs pull
```

### 새로 클론하는 경우

```bash
git clone <repo-url>
cd On-Voice
git lfs pull   # 클론 직후 모델이 안 받아졌다면 실행
```

## 4. 정상 적용 확인

아래 명령으로 파일 **크기**와 **타입**을 확인합니다.

```bash
ls -la frontend/OnVoice/Whisper_CoreML_Model/AudioEncoder.mlmodelc/weights/weight.bin
file  frontend/OnVoice/Whisper_CoreML_Model/AudioEncoder.mlmodelc/weights/weight.bin
```

| 상태 | weight.bin 크기 | `file` 결과 |
| :--- | :--- | :--- |
| 정상 | 약 16MB (16422784) | `data` 등 바이너리 |
| 포인터만 받아짐 (실패) | 약 130 bytes | `ASCII text` (`version https://git-lfs...`) |

한 번에 확인하려면:

```bash
git lfs ls-files                                 # 12개 파일이 떠야 함
du -sh frontend/OnVoice/Whisper_CoreML_Model     # 약 73M 이어야 함
```

폴더 용량이 73M 근처면 정상, 1MB 미만이면 `git lfs pull`이 안 된 상태입니다.

## 5. 빌드

위 확인이 정상이면 Xcode에서 평소처럼 빌드/실행하면 모델이 앱 번들에 포함되어 온디바이스로 동작합니다.

## 자주 겪는 함정

- **`git lfs install` 없이 `git pull`만 한 경우**
  포인터 파일만 갱신됩니다. `git lfs pull`을 별도로 실행하세요.
- **`git lfs install`을 나중에 한 경우**
  기존 포인터 파일이 자동으로 교체되지 않습니다. `git lfs pull`
  (또는 `git lfs checkout`)을 실행하세요.
- **시뮬레이터에서 안 될 때**
  CoreML / Neural Engine 동작이 실기기와 달라 로드·추론이 실패할 수 있습니다.
  가능하면 실기기에서 검증하세요.
- **CI / 배포 빌드에서 안 될 때**
  CI 러너에도 Git LFS가 설치·pull 되어야 합니다. 위와 동일한 원인입니다.
