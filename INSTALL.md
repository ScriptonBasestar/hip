# Hip 설치 가이드

Hip (Handy Infrastructure Provisioner)를 설치하는 방법을 안내합니다.

> **중요**: `gem install hip` 명령은 다른 gem(hostname resolver)을 설치합니다.
> 아래 안내된 방법을 사용하세요.

---

## 📦 설치 방법

### 방법 1: GitHub Packages (권장) ⭐

GitHub의 Ruby gem 레지스트리를 통해 설치합니다.

```bash
# GitHub Personal Access Token 필요 (read:packages 권한)
# https://github.com/settings/tokens 에서 생성

gem install hip --source "https://rubygems.pkg.github.com/ScriptonBasestar"
```

**Gemfile 사용:**

```ruby
source "https://rubygems.pkg.github.com/ScriptonBasestar" do
  gem "hip"
end
```

**인증 설정:**

```bash
# ~/.gem/credentials 파일에 추가
echo ":github: Bearer YOUR_GITHUB_TOKEN" >> ~/.gem/credentials
chmod 0600 ~/.gem/credentials
```

---

### 방법 2: Git 저장소에서 직접 설치 (간편) ⭐

Bundler를 사용하여 GitHub 저장소에서 직접 설치합니다.

**Gemfile 사용:**

```ruby
# Gemfile
gem 'hip', git: 'https://github.com/ScriptonBasestar/hip.git'

# 특정 태그 버전:
gem 'hip', git: 'https://github.com/ScriptonBasestar/hip.git', tag: 'v8.2.8'

# 특정 브랜치:
gem 'hip', git: 'https://github.com/ScriptonBasestar/hip.git', branch: 'master'
```

```bash
bundle install
```

**명령줄 직접 설치:**

```bash
# specific_install gem 설치 (처음 한 번만)
gem install specific_install

# hip 설치
gem specific_install https://github.com/ScriptonBasestar/hip.git
```

---

### 방법 3: GitHub Releases에서 다운로드

[Releases 페이지](https://github.com/ScriptonBasestar/hip/releases)에서 `.gem` 파일을 다운로드하여 설치합니다.

**수동 다운로드:**

1. https://github.com/ScriptonBasestar/hip/releases 방문
2. 최신 릴리스에서 `hip-X.X.X.gem` 다운로드
3. 설치:

```bash
gem install hip-8.2.8.gem
```

**wget/curl 사용:**

```bash
# 최신 릴리스 다운로드 (버전 번호 확인 필요)
wget https://github.com/ScriptonBasestar/hip/releases/download/v8.2.8/hip-8.2.8.gem
gem install hip-8.2.8.gem
```

---

### 방법 4: 로컬 소스코드 빌드 (개발자용)

저장소를 클론하여 직접 빌드합니다.

```bash
# 1. 저장소 클론
git clone https://github.com/ScriptonBasestar/hip.git
cd hip

# 2. 의존성 설치
bundle install

# 3. 빌드 및 설치
bundle exec rake install:local
```

**개발 모드 실행 (설치 없이):**

```bash
bundle exec exe/hip --help
```

---

## ✅ 설치 확인

설치 후 다음 명령어로 확인:

```bash
hip --version
# 출력: 8.2.8 (또는 최신 버전)

hip --help
# Hip 명령어 도움말 출력
```

---

## 🔧 Shell 통합 (선택사항)

Hip 명령을 더 간편하게 사용하려면 shell에 통합할 수 있습니다.

```bash
# Bash
echo 'eval "$(hip console)"' >> ~/.bashrc
source ~/.bashrc

# Zsh
echo 'eval "$(hip console)"' >> ~/.zshrc
source ~/.zshrc
```

Shell 통합 후에는 `hip` 접두사 없이 명령 사용 가능:

```bash
hip rails console  # Before
rails console      # After shell integration
```

---

## 🐛 문제 해결

### Q: `gem install hip`이 다른 gem을 설치합니다

**A**: RubyGems.org에 동일한 이름의 다른 gem이 존재합니다. 위의 설치 방법을 사용하세요.

### Q: GitHub Packages 인증 오류

**A**: Personal Access Token이 필요합니다:

1. https://github.com/settings/tokens 방문
2. "Generate new token (classic)" 선택
3. `read:packages` 권한 체크
4. 토큰 생성 후 설치 명령에 사용

### Q: `specific_install`이 없다는 오류

**A**: 먼저 설치하세요:

```bash
gem install specific_install
```

### Q: Permission denied 오류

**A**: `sudo` 사용 또는 rbenv/rvm 환경 사용 권장:

```bash
# sudo 사용 (권장하지 않음)
sudo gem install hip-8.2.8.gem

# 또는 사용자 디렉토리에 설치
gem install hip-8.2.8.gem --user-install
```

### Q: 이미 hip 0.3.0이 설치되어 있습니다

**A**: 두 버전이 공존할 수 있습니다. 최신 버전(8.x)이 우선 실행됩니다:

```bash
gem list hip
# hip (8.2.8, 0.3.0)  ← 정상

# 특정 버전 제거 (필요시)
gem uninstall hip --version 0.3.0
```

---

## 📚 다음 단계

설치 후 다음 문서를 참조하세요:

- **[README.md](README.md)** - Hip 사용법 및 기능 소개
- **[examples/](examples/)** - 설정 예제 및 사용 사례
- **[CLAUDE.md](CLAUDE.md)** - 프로젝트 개발 가이드

---

## 🆘 도움이 필요하신가요?

- **이슈 제출**: https://github.com/ScriptonBasestar/hip/issues
- **원본 프로젝트**: https://github.com/bibendi/dip
