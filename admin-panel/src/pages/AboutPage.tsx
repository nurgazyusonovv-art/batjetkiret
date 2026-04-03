import { MessageCircle, Send, Camera, Code2, Info, Zap, MapPin, Wallet, Star } from 'lucide-react';
import './AboutPage.css';

export default function AboutPage() {
  return (
    <div className="about-page">
      {/* Hero */}
      <div className="about-hero">
        <img src="/logo.png" alt="Баткен Экспресс" className="about-logo" />
        <h1>БАТКЕН ЭКСПРЕСС</h1>
        <p className="about-version">Версия 1.0.1 · Админ панель</p>
      </div>

      <div className="about-grid">
        {/* About app */}
        <div className="about-card">
          <div className="about-card-title">
            <Info size={18} />
            Программа жөнүндө
          </div>
          <p className="about-desc">
            Баткен Экспресс — Баткен шаарынын жана коңшу аймактарынын тез жеткирүү кызматы.
            Система колдонуучуларды, курьерлерди жана ишканаларды бир платформада бириктирет.
          </p>
          <div className="about-features">
            <div className="about-feature"><Zap size={15} /> Курьер аркылуу тез жеткирүү</div>
            <div className="about-feature"><MapPin size={15} /> Реалдуу убакытта курьердин жайгашуусун көрүү</div>
            <div className="about-feature"><Wallet size={15} /> Ички баланс жана онлайн-төлөм системасы</div>
            <div className="about-feature"><Star size={15} /> Курьерлерди жана кызматты баалоо</div>
          </div>
        </div>

        {/* How it works */}
        <div className="about-card">
          <div className="about-card-title">
            <Code2 size={18} />
            Кантип иштейт?
          </div>
          <div className="about-steps">
            <div className="about-step"><span className="step-num">1</span> Колдонуучу каттоодон өтүп, заказ берет</div>
            <div className="about-step"><span className="step-num">2</span> Тутум жакын курьерди автоматтык тандайт</div>
            <div className="about-step"><span className="step-num">3</span> Курьер заказды кабыл алып, жолго чыгат</div>
            <div className="about-step"><span className="step-num">4</span> Колдонуучу картада курьерди реалдуу убакытта көрөт</div>
            <div className="about-step"><span className="step-num">5</span> Жеткирилгенден кийин баланстан акы алынат</div>
            <div className="about-step"><span className="step-num">6</span> Админ панель аркылуу бардыгы башкарылат</div>
          </div>
        </div>

        {/* Developer */}
        <div className="about-card about-card-developer">
          <div className="about-card-title">
            <Code2 size={18} />
            Иштеп чыгуучу
          </div>
          <div className="developer-name">Nurgazy Uson uulu</div>
          <div className="developer-contacts">
            <a href="https://wa.me/996999310893" target="_blank" rel="noreferrer" className="contact-link whatsapp">
              <span className="contact-icon"><MessageCircle size={18} /></span>
              <div>
                <div className="contact-label">WhatsApp</div>
                <div className="contact-value">+996 999 310 893</div>
              </div>
            </a>
            <a href="https://t.me/nur93r" target="_blank" rel="noreferrer" className="contact-link telegram">
              <span className="contact-icon"><Send size={18} /></span>
              <div>
                <div className="contact-label">Telegram</div>
                <div className="contact-value">@nur93r</div>
              </div>
            </a>
            <a href="https://instagram.com/batkendik.mugalim" target="_blank" rel="noreferrer" className="contact-link instagram">
              <span className="contact-icon"><Camera size={18} /></span>
              <div>
                <div className="contact-label">Instagram</div>
                <div className="contact-value">@batkendik.mugalim</div>
              </div>
            </a>
          </div>
        </div>
      </div>

      <p className="about-copyright">© 2024–2025 Баткен Экспресс. Бардык укуктар корголгон.</p>
    </div>
  );
}
