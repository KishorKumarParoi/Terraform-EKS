from dataclasses import dataclass
import os


@dataclass(frozen=True)
class Settings:
    db_host: str = os.getenv("DB_HOST", "postgres")
    db_port: int = int(os.getenv("DB_PORT", "5432"))
    db_name: str = os.getenv("DB_NAME", "etl_platform")
    db_user: str = os.getenv("DB_USER", "etl_user")
    db_password: str = os.getenv("DB_PASSWORD", "etl_password")
    api_port: int = int(os.getenv("API_PORT", "8000"))
    grafana_admin_user: str = os.getenv("GRAFANA_ADMIN_USER", "admin")
    grafana_admin_password: str = os.getenv("GRAFANA_ADMIN_PASSWORD", "admin")

    @property
    def database_url(self) -> str:
        return (
            f"dbname={self.db_name} user={self.db_user} password={self.db_password} "
            f"host={self.db_host} port={self.db_port}"
        )


settings = Settings()
