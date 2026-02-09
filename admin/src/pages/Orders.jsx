import { useState, useEffect, useCallback, useRef } from 'react'
import { supabase } from '../lib/supabase'
import {
    Search,
    RefreshCw,
    File,
    Copy,
    Palette,
    BookOpen,
    FileText,
    CheckCircle,
    XCircle,
    Printer,
    Clock,
    Package,
    Image,
    FileType,
    Calendar,
    User,
    Mail,
    Hash,
    ChevronDown,
    ChevronUp,
    AlertCircle,
    Download,
    ExternalLink
} from 'lucide-react'

export default function Orders() {
    const [orders, setOrders] = useState([])
    const [filteredOrders, setFilteredOrders] = useState([])
    const [loading, setLoading] = useState(true)
    const [activeTab, setActiveTab] = useState('all')
    const [searchQuery, setSearchQuery] = useState('')
    const [updatingOrder, setUpdatingOrder] = useState(null)
    const [expandedOrder, setExpandedOrder] = useState(null)
    const [connectionStatus, setConnectionStatus] = useState('connecting')
    const channelRef = useRef(null)

    const tabs = [
        { id: 'all', label: 'All Orders', icon: FileText },
        { id: 'pending', label: 'Pending', icon: Clock },
        { id: 'processing', label: 'Processing', icon: Printer },
        { id: 'ready', label: 'Ready', icon: Package },
        { id: 'completed', label: 'Archived', icon: CheckCircle }
    ]

    const fetchOrders = useCallback(async () => {
        try {
            const { data, error } = await supabase
                .from('orders')
                .select(`
                    *,
                    students (id, name, roll_number, dept, email)
                `)
                .order('created_at', { ascending: false })

            if (error) throw error
            setOrders(data || [])
        } catch (error) {
            console.error('Error fetching orders:', error)
        } finally {
            setLoading(false)
        }
    }, [])

    // Setup realtime subscription
    useEffect(() => {
        fetchOrders()

        // Create a unique channel name
        const channelName = `orders-realtime-${Date.now()}`

        const channel = supabase
            .channel(channelName)
            .on('postgres_changes',
                {
                    event: '*',
                    schema: 'public',
                    table: 'orders'
                },
                (payload) => {
                    console.log('📦 Realtime order update:', payload.eventType, payload)
                    // Fetch fresh data on any change
                    fetchOrders()
                }
            )
            .subscribe((status, err) => {
                console.log('🔌 Realtime subscription status:', status)
                if (status === 'SUBSCRIBED') {
                    setConnectionStatus('connected')
                } else if (status === 'CLOSED' || status === 'CHANNEL_ERROR') {
                    setConnectionStatus('disconnected')
                } else {
                    setConnectionStatus('connecting')
                }
                if (err) {
                    console.error('Subscription error:', err)
                }
            })

        channelRef.current = channel

        return () => {
            if (channelRef.current) {
                supabase.removeChannel(channelRef.current)
            }
        }
    }, [fetchOrders])

    useEffect(() => {
        filterOrders()
    }, [orders, activeTab, searchQuery])

    const filterOrders = () => {
        let filtered = [...orders]

        // Filter by tab
        if (activeTab !== 'all') {
            if (activeTab === 'pending') {
                filtered = filtered.filter(o => o.status === 'pending')
            } else if (activeTab === 'processing') {
                filtered = filtered.filter(o => o.status === 'processing' || o.status === 'printing')
            } else if (activeTab === 'ready') {
                filtered = filtered.filter(o => o.status === 'ready')
            } else if (activeTab === 'completed') {
                filtered = filtered.filter(o => o.status === 'completed' || o.status === 'cancelled')
            }
        }

        // Filter by search
        if (searchQuery) {
            const query = searchQuery.toLowerCase()
            filtered = filtered.filter(o =>
                o.order_id?.toLowerCase().includes(query) ||
                o.students?.name?.toLowerCase().includes(query) ||
                o.students?.roll_number?.toLowerCase().includes(query) ||
                o.file_names?.some(f => f.toLowerCase().includes(query))
            )
        }

        setFilteredOrders(filtered)
    }

    const updateOrderStatus = async (orderId, newStatus) => {
        setUpdatingOrder(orderId)
        try {
            const updates = {
                status: newStatus,
                updated_at: new Date().toISOString()
            }

            if (newStatus === 'processing') {
                updates.processed_at = new Date().toISOString()
            } else if (newStatus === 'completed') {
                updates.picked_up_at = new Date().toISOString()
            }

            const { error } = await supabase
                .from('orders')
                .update(updates)
                .eq('id', orderId)

            if (error) throw error
            // Will be updated via realtime subscription
        } catch (error) {
            console.error('Error updating order:', error)
            alert('Failed to update order status')
        } finally {
            setUpdatingOrder(null)
        }
    }

    const getStatusConfig = (status) => {
        const config = {
            pending: { label: 'Pending', class: 'pending', icon: Clock, color: '#f59e0b' },
            processing: { label: 'Processing', class: 'processing', icon: RefreshCw, color: '#1E88E5' },
            printing: { label: 'Printing', class: 'printing', icon: Printer, color: '#8b5cf6' },
            ready: { label: 'Ready for Pickup', class: 'ready', icon: Package, color: '#22c55e' },
            completed: { label: 'Completed', class: 'completed', icon: CheckCircle, color: '#94a3b8' },
            cancelled: { label: 'Cancelled', class: 'cancelled', icon: XCircle, color: '#ef4444' }
        }
        return config[status] || { label: status, class: 'pending', icon: Clock, color: '#f59e0b' }
    }

    const getNextStatus = (currentStatus) => {
        const workflow = {
            pending: { next: 'processing', label: 'Start Processing', icon: RefreshCw },
            processing: { next: 'printing', label: 'Start Printing', icon: Printer },
            printing: { next: 'ready', label: 'Mark Ready', icon: Package },
            ready: { next: 'completed', label: 'Mark Picked Up', icon: CheckCircle }
        }
        return workflow[currentStatus]
    }

    const formatDate = (dateString) => {
        if (!dateString) return 'Not set'
        const date = new Date(dateString)
        return date.toLocaleString('en-IN', {
            day: '2-digit',
            month: 'short',
            year: 'numeric',
            hour: '2-digit',
            minute: '2-digit'
        })
    }

    const formatSlotTime = (dateString) => {
        if (!dateString) return null
        const date = new Date(dateString)
        return {
            date: date.toLocaleDateString('en-IN', { day: '2-digit', month: 'short' }),
            time: date.toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit' })
        }
    }

    const getTabCount = (tabId) => {
        if (tabId === 'all') return orders.length
        if (tabId === 'pending') return orders.filter(o => o.status === 'pending').length
        if (tabId === 'processing') return orders.filter(o => o.status === 'processing' || o.status === 'printing').length
        if (tabId === 'ready') return orders.filter(o => o.status === 'ready').length
        if (tabId === 'completed') return orders.filter(o => o.status === 'completed' || o.status === 'cancelled').length
        return 0
    }

    const getFileIcon = (fileName) => {
        const ext = fileName?.split('.').pop()?.toLowerCase()
        switch (ext) {
            case 'pdf':
                return { icon: FileType, color: '#ef4444' }
            case 'doc':
            case 'docx':
                return { icon: FileText, color: '#3b82f6' }
            case 'jpg':
            case 'jpeg':
            case 'png':
            case 'gif':
                return { icon: Image, color: '#22c55e' }
            default:
                return { icon: File, color: '#64748b' }
        }
    }

    const toggleOrderExpand = (orderId) => {
        setExpandedOrder(expandedOrder === orderId ? null : orderId)
    }

    if (loading) {
        return (
            <div className="loading-container">
                <div className="loading-spinner"></div>
            </div>
        )
    }

    return (
        <div className="fade-in">
            {/* Header */}
            <div className="orders-header">
                <div>
                    <h1>Orders</h1>
                    <p>Manage and process print orders</p>
                </div>
                <div className="header-actions">
                    <div className={`connection-status ${connectionStatus}`}>
                        <span className="status-dot"></span>
                        {connectionStatus === 'connected' ? 'Live Updates Active' :
                            connectionStatus === 'connecting' ? 'Connecting...' : 'Reconnecting...'}
                    </div>
                    <button className="btn btn-secondary" onClick={fetchOrders}>
                        <RefreshCw size={16} />
                        Refresh
                    </button>
                </div>
            </div>

            {/* Stats Row */}
            <div className="orders-stats">
                <div className="stat-item pending">
                    <Clock size={20} />
                    <div>
                        <span className="stat-value">{getTabCount('pending')}</span>
                        <span className="stat-label">Pending</span>
                    </div>
                </div>
                <div className="stat-item processing">
                    <Printer size={20} />
                    <div>
                        <span className="stat-value">{getTabCount('processing')}</span>
                        <span className="stat-label">In Progress</span>
                    </div>
                </div>
                <div className="stat-item ready">
                    <Package size={20} />
                    <div>
                        <span className="stat-value">{getTabCount('ready')}</span>
                        <span className="stat-label">Ready</span>
                    </div>
                </div>
                <div className="stat-item total">
                    <FileText size={20} />
                    <div>
                        <span className="stat-value">{orders.length}</span>
                        <span className="stat-label">Total Orders</span>
                    </div>
                </div>
            </div>

            {/* Search and Filters */}
            <div className="orders-filters">
                <div className="search-box" style={{ flex: 1, maxWidth: '400px' }}>
                    <Search size={18} />
                    <input
                        type="text"
                        className="form-input"
                        placeholder="Search orders, students, or files..."
                        value={searchQuery}
                        onChange={(e) => setSearchQuery(e.target.value)}
                    />
                </div>
            </div>

            {/* Tabs */}
            <div className="order-tabs">
                {tabs.map(tab => {
                    const TabIcon = tab.icon
                    const count = getTabCount(tab.id)
                    return (
                        <button
                            key={tab.id}
                            className={`order-tab ${activeTab === tab.id ? 'active' : ''}`}
                            onClick={() => setActiveTab(tab.id)}
                        >
                            <TabIcon size={16} />
                            <span>{tab.label}</span>
                            <span className="tab-count">{count}</span>
                        </button>
                    )
                })}
            </div>

            {/* Orders List */}
            {filteredOrders.length === 0 ? (
                <div className="card">
                    <div className="empty-state">
                        <FileText size={48} />
                        <h3>No orders found</h3>
                        <p>
                            {searchQuery
                                ? 'Try adjusting your search query'
                                : 'Orders will appear here when students place them'}
                        </p>
                    </div>
                </div>
            ) : (
                <div className="orders-grid">
                    {filteredOrders.map(order => {
                        const nextAction = getNextStatus(order.status)
                        const statusConfig = getStatusConfig(order.status)
                        const StatusIcon = statusConfig.icon
                        const isExpanded = expandedOrder === order.id
                        const slotTime = formatSlotTime(order.slot_time)
                        const fileNames = order.file_names || []

                        return (
                            <div key={order.id} className={`order-card-enhanced ${order.status}`}>
                                {/* Status Ribbon */}
                                <div className="order-ribbon" style={{ backgroundColor: statusConfig.color }}>
                                    <StatusIcon size={12} />
                                    {statusConfig.label}
                                </div>

                                {/* Order Header */}
                                <div className="order-header-section">
                                    <div className="order-id-section">
                                        <span className="order-number">{order.order_id}</span>
                                        <span className="order-time">{formatDate(order.created_at)}</span>
                                    </div>
                                    <div className="order-cost">₹{Number(order.cost || 0).toLocaleString()}</div>
                                </div>

                                {/* Student Info */}
                                <div className="student-info-card">
                                    <div className="student-avatar">
                                        {order.students?.name?.charAt(0) || 'S'}
                                    </div>
                                    <div className="student-details">
                                        <h4>{order.students?.name || 'Unknown Student'}</h4>
                                        <div className="student-meta">
                                            <span><Hash size={12} /> {order.students?.roll_number || 'N/A'}</span>
                                            <span><User size={12} /> {order.students?.dept || 'N/A'}</span>
                                        </div>
                                        {order.students?.email && (
                                            <span className="student-email">
                                                <Mail size={12} /> {order.students.email}
                                            </span>
                                        )}
                                    </div>
                                </div>

                                {/* Pickup Slot */}
                                {slotTime && (
                                    <div className="pickup-slot">
                                        <Calendar size={16} />
                                        <div>
                                            <span className="slot-label">Pickup Slot</span>
                                            <span className="slot-time">{slotTime.date} at {slotTime.time}</span>
                                        </div>
                                    </div>
                                )}

                                {/* Print Options */}
                                <div className="print-options-grid">
                                    <div className="print-option">
                                        <Copy size={14} />
                                        <span>{order.copies || 1} {(order.copies || 1) === 1 ? 'Copy' : 'Copies'}</span>
                                    </div>
                                    <div className="print-option">
                                        <Palette size={14} />
                                        <span>{order.is_color ? 'Color' : 'B&W'}</span>
                                    </div>
                                    <div className="print-option">
                                        <BookOpen size={14} />
                                        <span>{order.is_double_sided ? '2-Sided' : '1-Sided'}</span>
                                    </div>
                                    <div className="print-option">
                                        <File size={14} />
                                        <span>{order.paper_size || 'A4'}</span>
                                    </div>
                                </div>

                                {/* Files Section */}
                                {fileNames.length > 0 && (
                                    <div className="files-section">
                                        <div className="files-header">
                                            <button
                                                className="files-toggle"
                                                onClick={() => toggleOrderExpand(order.id)}
                                            >
                                                <FileText size={16} />
                                                <span>{fileNames.length} File{fileNames.length > 1 ? 's' : ''}</span>
                                                {isExpanded ? <ChevronUp size={16} /> : <ChevronDown size={16} />}
                                            </button>

                                            {/* Download All Button */}
                                            {order.file_urls && order.file_urls.length > 0 && (
                                                <button
                                                    className="btn btn-secondary btn-sm download-all-btn"
                                                    onClick={() => {
                                                        order.file_urls.forEach((url, i) => {
                                                            setTimeout(() => {
                                                                window.open(url, '_blank')
                                                            }, i * 300)
                                                        })
                                                    }}
                                                >
                                                    <Download size={14} />
                                                    Download All
                                                </button>
                                            )}
                                        </div>

                                        {isExpanded && (
                                            <div className="files-list">
                                                {fileNames.map((fileName, idx) => {
                                                    const fileInfo = getFileIcon(fileName)
                                                    const FileIcon = fileInfo.icon
                                                    const fileUrl = order.file_urls?.[idx]

                                                    return (
                                                        <div key={idx} className="file-item">
                                                            <div className="file-icon" style={{ backgroundColor: `${fileInfo.color}15`, color: fileInfo.color }}>
                                                                <FileIcon size={16} />
                                                            </div>
                                                            <span className="file-name">{fileName}</span>

                                                            {fileUrl ? (
                                                                <div className="file-actions">
                                                                    <a
                                                                        href={fileUrl}
                                                                        target="_blank"
                                                                        rel="noopener noreferrer"
                                                                        className="file-action-btn download"
                                                                        title="Download file"
                                                                    >
                                                                        <Download size={14} />
                                                                    </a>
                                                                    <a
                                                                        href={fileUrl}
                                                                        target="_blank"
                                                                        rel="noopener noreferrer"
                                                                        className="file-action-btn view"
                                                                        title="Open in new tab"
                                                                    >
                                                                        <ExternalLink size={14} />
                                                                    </a>
                                                                </div>
                                                            ) : (
                                                                <span className="file-no-url">No file uploaded</span>
                                                            )}
                                                        </div>
                                                    )
                                                })}
                                            </div>
                                        )}
                                    </div>
                                )}

                                {/* Actions */}
                                <div className="order-actions-section">
                                    {nextAction && (
                                        <button
                                            className="btn btn-primary"
                                            onClick={() => updateOrderStatus(order.id, nextAction.next)}
                                            disabled={updatingOrder === order.id}
                                        >
                                            {updatingOrder === order.id ? (
                                                <>
                                                    <RefreshCw size={14} className="spinning" />
                                                    Updating...
                                                </>
                                            ) : (
                                                <>
                                                    <nextAction.icon size={14} />
                                                    {nextAction.label}
                                                </>
                                            )}
                                        </button>
                                    )}

                                    {order.status === 'pending' && (
                                        <button
                                            className="btn btn-danger"
                                            onClick={() => updateOrderStatus(order.id, 'cancelled')}
                                            disabled={updatingOrder === order.id}
                                        >
                                            <XCircle size={14} />
                                            Cancel
                                        </button>
                                    )}

                                    {order.status === 'completed' && (
                                        <div className="completed-badge">
                                            <CheckCircle size={14} />
                                            Picked up {order.picked_up_at ? formatDate(order.picked_up_at) : ''}
                                        </div>
                                    )}

                                    {order.status === 'cancelled' && (
                                        <div className="cancelled-badge">
                                            <XCircle size={14} />
                                            Order Cancelled
                                        </div>
                                    )}
                                </div>
                            </div>
                        )
                    })}
                </div>
            )}
        </div>
    )
}
