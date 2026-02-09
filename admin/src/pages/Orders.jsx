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


const downloadFile = async (url, fileName) => {
    try {
        const response = await fetch(url)
        const blob = await response.blob()
        const blobUrl = window.URL.createObjectURL(blob)
        const link = document.createElement('a')
        link.href = blobUrl
        link.download = fileName
        document.body.appendChild(link)
        link.click()
        document.body.removeChild(link)
        window.URL.revokeObjectURL(blobUrl)
    } catch (error) {
        console.error('Download failed:', error)
        window.open(url, '_blank')
    }
}

const FilePreviewModal = ({ file, onClose }) => {
    if (!file) return null

    const isPdf = file.name?.toLowerCase().endsWith('.pdf')
    const isImage = ['jpg', 'jpeg', 'png', 'gif', 'webp'].some(ext => file.name?.toLowerCase().endsWith(ext))

    return (
        <div className="modal-overlay" onClick={onClose}>
            <div className="modal-content preview-modal" onClick={e => e.stopPropagation()}>
                <div className="modal-header">
                    <h3>{file.name}</h3>
                    <button className="btn-icon" onClick={onClose}><XCircle size={24} /></button>
                </div>
                <div className="modal-body">
                    {isImage ? (
                        <img src={file.url} alt={file.name} className="preview-image" />
                    ) : isPdf ? (
                        <iframe src={file.url} title={file.name} className="preview-frame" />
                    ) : (
                        <div className="preview-unsupported">
                            <FileText size={48} />
                            <p>Preview not available for this file type</p>
                            <button
                                onClick={() => downloadFile(file.url, file.name)}
                                className="btn btn-primary"
                            >
                                <Download size={16} /> Download to View
                            </button>
                        </div>
                    )}
                </div>
            </div>
        </div>
    )
}

export default function Orders() {
    const [orders, setOrders] = useState([])
    const [filteredOrders, setFilteredOrders] = useState([])
    const [loading, setLoading] = useState(true)
    const [activeTab, setActiveTab] = useState('all')
    const [searchQuery, setSearchQuery] = useState('')
    const [updatingOrder, setUpdatingOrder] = useState(null)
    const [expandedOrder, setExpandedOrder] = useState(null)
    const [previewFile, setPreviewFile] = useState(null)
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

    useEffect(() => {
        fetchOrders()
        const channelName = `orders-realtime-${Date.now()}`
        const channel = supabase
            .channel(channelName)
            .on('postgres_changes',
                { event: '*', schema: 'public', table: 'orders' },
                (payload) => {
                    console.log('📦 Realtime order update:', payload.eventType)
                    fetchOrders()
                }
            )
            .subscribe((status, err) => {
                if (status === 'SUBSCRIBED') setConnectionStatus('connected')
                else if (status === 'CLOSED' || status === 'CHANNEL_ERROR') setConnectionStatus('disconnected')
                else setConnectionStatus('connecting')
                if (err) console.error('Subscription error:', err)
            })

        channelRef.current = channel
        return () => {
            if (channelRef.current) supabase.removeChannel(channelRef.current)
        }
    }, [fetchOrders])

    useEffect(() => {
        filterOrders()
    }, [orders, activeTab, searchQuery])

    const filterOrders = () => {
        let filtered = [...orders]
        if (activeTab !== 'all') {
            if (activeTab === 'pending') filtered = filtered.filter(o => o.status === 'pending')
            else if (activeTab === 'processing') filtered = filtered.filter(o => ['processing', 'printing'].includes(o.status))
            else if (activeTab === 'ready') filtered = filtered.filter(o => o.status === 'ready')
            else if (activeTab === 'completed') filtered = filtered.filter(o => ['completed', 'cancelled'].includes(o.status))
        }
        if (searchQuery.trim()) {
            const query = searchQuery.toLowerCase()
            filtered = filtered.filter(o =>
                o.order_id?.toLowerCase().includes(query) ||
                o.students?.name?.toLowerCase().includes(query) ||
                o.students?.roll_number?.toLowerCase().includes(query) ||
                (o.file_names || []).some(f => f.toLowerCase().includes(query))
            )
        }
        setFilteredOrders(filtered)
    }

    const updateOrderStatus = async (orderId, newStatus) => {
        setUpdatingOrder(orderId)
        try {
            const updateData = { status: newStatus, updated_at: new Date().toISOString() }
            if (newStatus === 'completed') updateData.picked_up_at = new Date().toISOString()
            await supabase.from('orders').update(updateData).eq('id', orderId)
            await fetchOrders()
        } catch (error) {
            console.error('Error updating order:', error)
        } finally {
            setUpdatingOrder(null)
        }
    }

    const getStatusConfig = (status) => {
        const configs = {
            pending: { color: '#f59e0b', label: 'Pending', icon: Clock },
            processing: { color: '#3b82f6', label: 'Processing', icon: Printer },
            printing: { color: '#8b5cf6', label: 'Printing', icon: Printer },
            ready: { color: '#22c55e', label: 'Ready', icon: Package },
            completed: { color: '#64748b', label: 'Completed', icon: CheckCircle },
            cancelled: { color: '#ef4444', label: 'Cancelled', icon: XCircle }
        }
        return configs[status] || configs.pending
    }

    const getNextStatus = (current) => {
        const flow = {
            pending: { next: 'processing', label: 'Start Processing', icon: Printer },
            processing: { next: 'ready', label: 'Mark Ready', icon: Package },
            ready: { next: 'completed', label: 'Mark Picked Up', icon: CheckCircle }
        }
        return flow[current] || null
    }

    const formatDate = (dateString) => {
        if (!dateString) return 'N/A'
        return new Date(dateString).toLocaleDateString('en-IN', {
            day: '2-digit', month: 'short', hour: '2-digit', minute: '2-digit'
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
        if (tabId === 'processing') return orders.filter(o => ['processing', 'printing'].includes(o.status)).length
        if (tabId === 'ready') return orders.filter(o => o.status === 'ready').length
        if (tabId === 'completed') return orders.filter(o => ['completed', 'cancelled'].includes(o.status)).length
        return 0
    }

    const getFileIcon = (fileName) => {
        const ext = fileName?.split('.').pop()?.toLowerCase()
        if (ext === 'pdf') return { icon: FileType, color: '#ef4444' }
        if (['doc', 'docx'].includes(ext)) return { icon: FileText, color: '#3b82f6' }
        if (['jpg', 'jpeg', 'png', 'gif'].includes(ext)) return { icon: Image, color: '#22c55e' }
        return { icon: File, color: '#64748b' }
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
            {previewFile && (
                <FilePreviewModal file={previewFile} onClose={() => setPreviewFile(null)} />
            )}

            {/* Header */}
            <div className="orders-header">
                <div>
                    <h1>Orders</h1>
                    <p>Manage and process print orders</p>
                </div>
                <div className="header-actions">
                    <div className={`connection-status ${connectionStatus}`}>
                        <span className="status-dot"></span>
                        {connectionStatus === 'connected' ? 'Live' : connectionStatus === 'connecting' ? 'Connecting...' : 'Offline'}
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
                        <span className="stat-value">{orders.filter(o => o.status === 'pending').length}</span>
                        <span className="stat-label">Pending</span>
                    </div>
                </div>
                <div className="stat-item processing">
                    <Printer size={20} />
                    <div>
                        <span className="stat-value">{orders.filter(o => ['processing', 'printing'].includes(o.status)).length}</span>
                        <span className="stat-label">In Progress</span>
                    </div>
                </div>
                <div className="stat-item ready">
                    <Package size={20} />
                    <div>
                        <span className="stat-value">{orders.filter(o => o.status === 'ready').length}</span>
                        <span className="stat-label">Ready</span>
                    </div>
                </div>
                <div className="stat-item total">
                    <FileText size={20} />
                    <div>
                        <span className="stat-value">{orders.length}</span>
                        <span className="stat-label">Total</span>
                    </div>
                </div>
            </div>

            {/* Toolbar: Search & Filters */}
            <div className="orders-toolbar" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '20px', gap: '16px', flexWrap: 'wrap' }}>
                {/* Search */}
                <div className="search-box" style={{ width: '300px' }}>
                    <Search size={18} />
                    <input
                        type="text"
                        className="form-input"
                        placeholder="Search orders, students, or files..."
                        value={searchQuery}
                        onChange={(e) => setSearchQuery(e.target.value)}
                    />
                </div>

                {/* Tabs */}
                <div className="order-tabs" style={{ marginBottom: 0 }}>
                    {tabs.map(tab => {
                        const TabIcon = tab.icon
                        return (
                            <button
                                key={tab.id}
                                className={`order-tab ${activeTab === tab.id ? 'active' : ''}`}
                                onClick={() => setActiveTab(tab.id)}
                            >
                                <TabIcon size={16} />
                                <span>{tab.label}</span>
                                <span className="tab-count">{getTabCount(tab.id)}</span>
                            </button>
                        )
                    })}
                </div>
            </div>

            {/* Orders List */}
            {filteredOrders.length === 0 ? (
                <div className="card">
                    <div className="empty-state">
                        <FileText size={48} />
                        <h3>No orders found</h3>
                        <p>{searchQuery ? 'Try adjusting your search' : 'Orders will appear when placed'}</p>
                    </div>
                </div>
            ) : (
                <div className="orders-list-compact">
                    {/* List Header */}
                    <div className="orders-list-header">
                        <span className="col-status">Status</span>
                        <span className="col-order">Order</span>
                        <span className="col-student">Student</span>
                        <span className="col-files">Files</span>
                        <span className="col-cost">Cost</span>
                        <span className="col-time">Time</span>
                        <span className="col-expand"></span>
                    </div>

                    {filteredOrders.map(order => {
                        const nextAction = getNextStatus(order.status)
                        const statusConfig = getStatusConfig(order.status)
                        const StatusIcon = statusConfig.icon
                        const isExpanded = expandedOrder === order.id
                        const slotTime = formatSlotTime(order.slot_time)
                        const fileNames = order.file_names || []

                        return (
                            <div key={order.id} className={`order-row ${order.status} ${isExpanded ? 'expanded' : ''}`}>
                                {/* Compact Row */}
                                <div className="order-row-compact" onClick={() => toggleOrderExpand(order.id)}>
                                    <div className="col-status">
                                        <span className="status-badge" style={{ backgroundColor: statusConfig.color }}>
                                            <StatusIcon size={12} />
                                            <span className="status-text">{statusConfig.label}</span>
                                        </span>
                                    </div>
                                    <div className="col-order">
                                        <span className="order-id-compact">{order.order_id}</span>
                                    </div>
                                    <div className="col-student">
                                        <div className="student-compact">
                                            <span className="student-avatar-mini">{order.students?.name?.charAt(0) || 'S'}</span>
                                            <span className="student-name-compact">{order.students?.name || 'Unknown'}</span>
                                        </div>
                                    </div>
                                    <div className="col-files">
                                        <span className="files-badge">
                                            <FileText size={12} />
                                            {fileNames.length}
                                        </span>
                                        {order.is_color && <span className="color-badge"><Palette size={10} /></span>}
                                    </div>
                                    <div className="col-cost">
                                        <span className="cost-value">₹{Number(order.cost || 0).toLocaleString()}</span>
                                    </div>
                                    <div className="col-time">
                                        <span className="time-value">{formatDate(order.created_at)}</span>
                                    </div>
                                    <div className="col-expand">
                                        {isExpanded ? <ChevronUp size={18} /> : <ChevronDown size={18} />}
                                    </div>
                                </div>

                                {/* Expanded Details */}
                                {isExpanded && (
                                    <div className="order-expanded">
                                        <div className="expanded-grid">
                                            {/* Student Details - Refactored for alignment */}
                                            <div className="expanded-section student-section-container">
                                                <h5>Student</h5>
                                                <div className="student-detail-card">
                                                    <div className="student-header-row">
                                                        <div className="student-avatar-lg">
                                                            {order.students?.name?.charAt(0) || 'S'}
                                                        </div>
                                                        <div className="student-main-info">
                                                            <div className="student-name-lg">{order.students?.name || 'Unknown'}</div>
                                                            <div className="student-role-badge">Student</div>
                                                        </div>
                                                    </div>

                                                    <div className="student-info-grid">
                                                        {order.students?.dept && (
                                                            <div className="info-row">
                                                                <BookOpen size={14} className="info-icon" />
                                                                <span>{order.students.dept}</span>
                                                            </div>
                                                        )}
                                                        <div className="info-row">
                                                            <Hash size={14} className="info-icon" />
                                                            <span>Roll {order.students?.roll_number || 'N/A'}</span>
                                                        </div>
                                                        {order.students?.email && (
                                                            <div className="info-row email-row">
                                                                <Mail size={14} className="info-icon" />
                                                                <span>{order.students.email}</span>
                                                            </div>
                                                        )}
                                                    </div>
                                                </div>
                                            </div>

                                            {/* Print Settings */}
                                            <div className="expanded-section">
                                                <h5>Print Settings</h5>
                                                <div className="settings-grid">
                                                    <div className="setting-item">
                                                        <Copy size={16} />
                                                        <div>
                                                            <span className="setting-value">{order.copies || 1}</span>
                                                            <span className="setting-label">Copies</span>
                                                        </div>
                                                    </div>
                                                    <div className="setting-item">
                                                        <Palette size={16} />
                                                        <div>
                                                            <span className="setting-value">{order.is_color ? 'Color' : 'B&W'}</span>
                                                            <span className="setting-label">Print Mode</span>
                                                        </div>
                                                    </div>
                                                    <div className="setting-item">
                                                        <BookOpen size={16} />
                                                        <div>
                                                            <span className="setting-value">{order.is_double_sided ? '2-Sided' : '1-Sided'}</span>
                                                            <span className="setting-label">Layout</span>
                                                        </div>
                                                    </div>
                                                    <div className="setting-item">
                                                        <File size={16} />
                                                        <div>
                                                            <span className="setting-value">{order.paper_size || 'A4'}</span>
                                                            <span className="setting-label">Size</span>
                                                        </div>
                                                    </div>
                                                </div>
                                            </div>

                                            {/* Pickup Slot */}
                                            {slotTime && (
                                                <div className="expanded-section">
                                                    <h5>Pickup Slot</h5>
                                                    <div className="pickup-badge-lg">
                                                        <Calendar size={20} />
                                                        <div>
                                                            <div className="pickup-date">{slotTime.date}</div>
                                                            <div className="pickup-time">{slotTime.time}</div>
                                                        </div>
                                                    </div>
                                                </div>
                                            )}

                                            {/* Files - Refactored for Preview */}
                                            <div className="expanded-section files-section-lg">
                                                <div className="files-header-row">
                                                    <h5>Files ({fileNames.length})</h5>
                                                    {order.file_urls?.length > 0 && (
                                                        <button
                                                            className="btn btn-sm btn-secondary"
                                                            onClick={(e) => {
                                                                e.stopPropagation()
                                                                order.file_urls.forEach((url, i) => {
                                                                    const fileName = order.file_names?.[i] || `file-${i + 1}`
                                                                    setTimeout(() => downloadFile(url, fileName), i * 500)
                                                                })
                                                            }}
                                                        >
                                                            <Download size={14} /> Download All
                                                        </button>
                                                    )}
                                                </div>
                                                <div className="files-grid">
                                                    {fileNames.map((fileName, idx) => {
                                                        const fileInfo = getFileIcon(fileName)
                                                        const FileIcon = fileInfo.icon
                                                        const fileUrl = order.file_urls?.[idx]

                                                        return (
                                                            <div key={idx} className="file-card">
                                                                <div className="file-icon-wrapper" style={{ color: fileInfo.color, backgroundColor: `${fileInfo.color}15` }}>
                                                                    <FileIcon size={24} />
                                                                </div>
                                                                <div className="file-info">
                                                                    <div className="file-name" title={fileName}>{fileName}</div>
                                                                    <div className="file-actions-row">
                                                                        {fileUrl && (
                                                                            <>
                                                                                <button
                                                                                    className="action-link view-link"
                                                                                    onClick={(e) => {
                                                                                        e.stopPropagation()
                                                                                        setPreviewFile({ name: fileName, url: fileUrl })
                                                                                    }}
                                                                                >
                                                                                    Preview
                                                                                </button>
                                                                                <span className="separator">•</span>
                                                                                <button
                                                                                    className="action-link download-link"
                                                                                    onClick={(e) => {
                                                                                        e.stopPropagation()
                                                                                        downloadFile(fileUrl, fileName)
                                                                                    }}
                                                                                >
                                                                                    Download
                                                                                </button>
                                                                            </>
                                                                        )}
                                                                    </div>
                                                                </div>
                                                            </div>
                                                        )
                                                    })}
                                                </div>
                                            </div>
                                        </div>

                                        {/* Actions */}
                                        <div className="expanded-actions">
                                            {nextAction && (
                                                <button
                                                    className="btn btn-primary"
                                                    onClick={(e) => {
                                                        e.stopPropagation()
                                                        updateOrderStatus(order.id, nextAction.next)
                                                    }}
                                                    disabled={updatingOrder === order.id}
                                                >
                                                    {updatingOrder === order.id ? (
                                                        <><RefreshCw size={14} className="spinning" /> Updating...</>
                                                    ) : (
                                                        <><nextAction.icon size={14} /> {nextAction.label}</>
                                                    )}
                                                </button>
                                            )}
                                            {order.status === 'pending' && (
                                                <button
                                                    className="btn btn-danger"
                                                    onClick={(e) => {
                                                        e.stopPropagation()
                                                        updateOrderStatus(order.id, 'cancelled')
                                                    }}
                                                    disabled={updatingOrder === order.id}
                                                >
                                                    <XCircle size={14} /> Cancel
                                                </button>
                                            )}
                                            {order.status === 'completed' && (
                                                <span className="completed-badge-inline">
                                                    <CheckCircle size={14} /> Order Completed & Picked Up
                                                </span>
                                            )}
                                            {order.status === 'cancelled' && (
                                                <span className="cancelled-badge-inline">
                                                    <XCircle size={14} /> Order Cancelled
                                                </span>
                                            )}
                                        </div>
                                    </div>
                                )}
                            </div>
                        )
                    })}
                </div>
            )}
        </div>
    )
}
