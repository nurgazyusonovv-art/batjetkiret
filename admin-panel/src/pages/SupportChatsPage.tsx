import { useEffect, useRef, useState } from 'react';
import { MessageSquare, Send, RefreshCw } from 'lucide-react';
import api from '@/services/api';
import './SupportChatsPage.css';

interface SupportChat {
  chat_id: number;
  user_id: number;
  user_name: string | null;
  user_phone: string | null;
  last_message: string | null;
  last_message_at: string | null;
  unread_count: number;
  created_at: string;
}

interface ChatMessage {
  id: number;
  sender_id: number;
  text: string;
  created_at: string | null;
  is_read: boolean;
}

export default function SupportChatsPage() {
  const [chats, setChats] = useState<SupportChat[]>([]);
  const [selectedChatId, setSelectedChatId] = useState<number | null>(null);
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [inputText, setInputText] = useState('');
  const [chatsLoading, setChatsLoading] = useState(true);
  const [msgsLoading, setMsgsLoading] = useState(false);
  const [sending, setSending] = useState(false);
  const messagesEndRef = useRef<HTMLDivElement>(null);
  const pollRef = useRef<ReturnType<typeof setInterval> | null>(null);

  // ── Load chat list ──────────────────────────────────────────────
  const loadChats = async () => {
    try {
      const res = await api.get<SupportChat[]>('/admin/support-chats', {
        params: { limit: 100 },
      });
      setChats(res.data.sort((a, b) => {
        const ta = a.last_message_at ?? a.created_at;
        const tb = b.last_message_at ?? b.created_at;
        return new Date(tb).getTime() - new Date(ta).getTime();
      }));
    } catch (e) {
      console.error('Failed to load support chats', e);
    } finally {
      setChatsLoading(false);
    }
  };

  // ── Load messages for selected chat ────────────────────────────
  const loadMessages = async (chatId: number) => {
    try {
      const res = await api.get<ChatMessage[]>(`/chat/${chatId}/messages`);
      setMessages(res.data);
    } catch (e) {
      console.error('Failed to load messages', e);
    }
  };

  // ── Mark all messages as read ───────────────────────────────────
  const markRead = async (chatId: number) => {
    try {
      await api.post(`/chat/${chatId}/read-messages`);
      setChats(prev =>
        prev.map(c => c.chat_id === chatId ? { ...c, unread_count: 0 } : c)
      );
    } catch (_) {}
  };

  // ── Select a chat ───────────────────────────────────────────────
  const selectChat = async (chatId: number) => {
    setSelectedChatId(chatId);
    setMsgsLoading(true);
    setMessages([]);
    try {
      await loadMessages(chatId);
      await markRead(chatId);
    } finally {
      setMsgsLoading(false);
    }
  };

  // ── Send message ────────────────────────────────────────────────
  const sendMessage = async () => {
    if (!selectedChatId || !inputText.trim() || sending) return;
    const text = inputText.trim();
    setInputText('');
    setSending(true);
    try {
      await api.post(`/chat/${selectedChatId}/send`, null, {
        params: { text },
      });
      await loadMessages(selectedChatId);
      await loadChats();
    } catch (e) {
      console.error('Failed to send message', e);
      setInputText(text);
    } finally {
      setSending(false);
    }
  };

  // ── Auto-scroll ─────────────────────────────────────────────────
  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages]);

  // ── Initial load + polling ──────────────────────────────────────
  useEffect(() => {
    loadChats();
    const chatsPoll = setInterval(loadChats, 15000);
    return () => clearInterval(chatsPoll);
  }, []);

  useEffect(() => {
    if (pollRef.current) clearInterval(pollRef.current);
    if (!selectedChatId) return;

    pollRef.current = setInterval(async () => {
      await loadMessages(selectedChatId);
    }, 5000);

    return () => {
      if (pollRef.current) clearInterval(pollRef.current);
    };
  }, [selectedChatId]);

  // ── Format date ─────────────────────────────────────────────────
  const fmt = (iso: string | null) => {
    if (!iso) return '';
    const d = new Date(iso);
    const now = new Date();
    const isToday =
      d.getDate() === now.getDate() &&
      d.getMonth() === now.getMonth() &&
      d.getFullYear() === now.getFullYear();
    if (isToday) {
      return d.toLocaleTimeString('ru-RU', { hour: '2-digit', minute: '2-digit' });
    }
    return d.toLocaleString('ru-RU', {
      day: '2-digit',
      month: '2-digit',
      hour: '2-digit',
      minute: '2-digit',
    });
  };

  const selectedChat = chats.find(c => c.chat_id === selectedChatId);
  const totalUnread = chats.reduce((s, c) => s + c.unread_count, 0);

  return (
    <div className="support-page">
      {/* ── Sidebar ── */}
      <div className="support-sidebar">
        <div className="support-sidebar-header">
          <div className="support-sidebar-title">
            <MessageSquare size={20} />
            <span>Колдоо чаттары</span>
            {totalUnread > 0 && (
              <span className="support-unread-badge">{totalUnread}</span>
            )}
          </div>
          <button className="support-refresh-btn" onClick={loadChats} title="Жаңылоо">
            <RefreshCw size={16} />
          </button>
        </div>

        {chatsLoading ? (
          <div className="support-loading">Жүктөлүүдө...</div>
        ) : chats.length === 0 ? (
          <div className="support-empty-list">Чат жок</div>
        ) : (
          <div className="support-chat-list">
            {chats.map(chat => (
              <div
                key={chat.chat_id}
                className={`support-chat-item ${selectedChatId === chat.chat_id ? 'active' : ''} ${chat.unread_count > 0 ? 'has-unread' : ''}`}
                onClick={() => selectChat(chat.chat_id)}
              >
                <div className="chat-item-avatar">
                  {(chat.user_name || chat.user_phone || 'U')[0].toUpperCase()}
                </div>
                <div className="chat-item-info">
                  <div className="chat-item-top">
                    <span className="chat-item-name">
                      {chat.user_name || chat.user_phone || `User #${chat.user_id}`}
                    </span>
                    <span className="chat-item-time">{fmt(chat.last_message_at)}</span>
                  </div>
                  <div className="chat-item-bottom">
                    <span className="chat-item-preview">
                      {chat.last_message || 'Билдирүү жок'}
                    </span>
                    {chat.unread_count > 0 && (
                      <span className="chat-item-badge">{chat.unread_count}</span>
                    )}
                  </div>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>

      {/* ── Chat window ── */}
      <div className="support-chat-window">
        {!selectedChatId ? (
          <div className="support-no-chat">
            <MessageSquare size={48} color="#d1d5db" />
            <p>Чатты тандаңыз</p>
          </div>
        ) : (
          <>
            {/* Header */}
            <div className="support-chat-header">
              <div className="chat-header-avatar">
                {(selectedChat?.user_name || selectedChat?.user_phone || 'U')[0].toUpperCase()}
              </div>
              <div>
                <div className="chat-header-name">
                  {selectedChat?.user_name || selectedChat?.user_phone || `User #${selectedChat?.user_id}`}
                </div>
                {selectedChat?.user_phone && selectedChat.user_name && (
                  <div className="chat-header-phone">{selectedChat.user_phone}</div>
                )}
              </div>
            </div>

            {/* Messages */}
            <div className="support-messages">
              {msgsLoading ? (
                <div className="support-loading">Жүктөлүүдө...</div>
              ) : messages.length === 0 ? (
                <div className="support-no-messages">Билдирүүлөр жок</div>
              ) : (
                messages.map(msg => {
                  const isAdmin = msg.sender_id !== selectedChat?.user_id;
                  return (
                    <div
                      key={msg.id}
                      className={`support-msg ${isAdmin ? 'msg-admin' : 'msg-user'}`}
                    >
                      <div className="msg-bubble">
                        <p className="msg-text">{msg.text}</p>
                        <span className="msg-time">{fmt(msg.created_at)}</span>
                      </div>
                    </div>
                  );
                })
              )}
              <div ref={messagesEndRef} />
            </div>

            {/* Input */}
            <div className="support-input-row">
              <input
                className="support-input"
                placeholder="Жооп жазыңыз..."
                value={inputText}
                onChange={e => setInputText(e.target.value)}
                onKeyDown={e => e.key === 'Enter' && !e.shiftKey && sendMessage()}
                disabled={sending}
              />
              <button
                className="support-send-btn"
                onClick={sendMessage}
                disabled={sending || !inputText.trim()}
              >
                <Send size={18} />
              </button>
            </div>
          </>
        )}
      </div>
    </div>
  );
}
