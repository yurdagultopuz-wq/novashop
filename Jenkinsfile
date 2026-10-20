pipeline {
    agent any

    environment {
        // Model A: 127.0.0.1:18082 veya Model B: studentXX-harbor.devopsatolyesi.com
        HARBOR_HOST = "${env.HARBOR_HOST ?: '127.0.0.1:18082'}"
        HARBOR_PROJECT = 'novashop'
        IMAGE_NAME = "${HARBOR_HOST}/${HARBOR_PROJECT}/novashop-ui"
        // Harbor robot hesabı kimlik bilgileri Jenkins Credentials Store'da tanımlıdır
        HARBOR_CREDS = credentials('harbor-robot-credentials')
    }

    stages {
        stage('1. Kaynak Kod ve Kontrol') {
            steps {
                echo "=== NovaShop Kurumsal CI/CD Pipeline Başlatılıyor ==="
                sh 'git --version'
                sh 'java -version || true'
            }
        }

        stage('2. Birim Testler (Java 21)') {
            steps {
                dir('src/ui') {
                    echo "Spring Boot Actuator ve UI birim testleri çalıştırılıyor..."
                    sh './mvnw clean test -B'
                }
            }
        }

        stage('3. Güvenlik ve Gizli Bilgi Taraması') {
            steps {
                echo "DevSecOps Kalite Kapısı denetleniyor..."
                sh 'bash scripts/verify/verify-lab-08.sh'
            }
        }

        stage('4. Multi-Stage Docker Build') {
            steps {
                script {
                    def shortSha = sh(script: "git rev-parse --short=8 HEAD", returnStdout: true).trim()
                    env.IMAGE_TAG = "sha-${shortSha}"
                }
                echo "Hedef İmaj: ${IMAGE_NAME}:${IMAGE_TAG}"
                sh "docker build -t ${IMAGE_NAME}:${IMAGE_TAG} src/ui"
                
                // Non-root kontrolü
                sh """
                    USER_ID=\$(docker image inspect ${IMAGE_NAME}:${IMAGE_TAG} --format '{{.Config.User}}')
                    if [ "\$USER_ID" != "appuser" ] && [ "\$USER_ID" != "1000" ]; then
                        echo "HATA: İmaj non-root değil!"
                        exit 1
                    fi
                """
            }
        }

        stage('5. Harbor Registry Push (Değiştirilemez Etiket)') {
            steps {
                echo "Harbor'a Robot Account ile giriş yapılıyor..."
                sh """
                    echo "\$HARBOR_CREDS_PSW" | docker login ${HARBOR_HOST} -u "\$HARBOR_CREDS_USR" --password-stdin
                    docker push ${IMAGE_NAME}:${IMAGE_TAG}
                """
            }
        }
    }

    post {
        always {
            sh 'docker logout ${HARBOR_HOST} || true'
            cleanWs()
        }
        success {
            echo "✅ Pipeline başarıyla tamamlandı: İmaj Harbor Registry'de yayınlandı."
        }
        failure {
            echo "❌ Pipeline başarısız oldu! Lütfen logları inceleyin."
        }
    }
}
