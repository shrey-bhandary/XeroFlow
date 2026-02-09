import { useState, useEffect } from 'react'
import { supabase } from '../lib/supabase'
import {
    Search,
    Filter,
    RefreshCw,
    ChevronDown,
    File,
    Copy,
    Palette,
    BookOpen,
    FileText,
    CheckCircle,
    XCircle,
    Printer,
    Clock,
    Package
} from 'lucide-react'

export default function Orders() {
    const [orders, setOrders] = useState([])
    const [filteredOrders, setFilteredOrders] = useState([])
    const [loading, setLoading] = useState(true)
    const [activeTab, setActiveTab] = useState('all')
    const [searchQuery, setSearchQuery] = useState('')
    const [updatingOrder, setUpdatingOrder] = useState(null)

    const tabs = [
        { id: 'all', label: 'All Orders' },
        { id: 'pending', label: 'Pending' },
        { id: 'processing', label: 'Processing' },
        { id: 'ready', label: 'Ready' },
        { id: 'completed', label: 'Completed' }
    ]

    useEffect(() => {
        fetchOrders()

        // Set up realtime subscription for instant updates
        const channel = supabase
            .channel('orders-realtime')
            .on('postgres_changes',
                { event: '*', schema: 'public', table: 'orders' },
                (payload) => {
                    console.log('Realtime update:', payload)
                    fetchOrders()
                }
            )
            .subscribe((status) => {
                console.log('Realtime subscription status:', status)
            })

        return () => {
            supabase.removeChannel(channel)
        }
    }, [])

    useEffect(() => {
        filterOrders()
    }, [orders, activeTab, searchQuery])

    const fetchOrders = async () => {
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
    }

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
                o.students?.roll_number?.toLowerCase().includes(query)
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

            // Add timestamps for specific statuses
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

    const getStatusBadge = (status) => {
        const statusConfig = {
            pending: { label: 'Pending', class: 'pending', icon: Clock },
            processing: { label: 'Processing', class: 'processing', icon: RefreshCw },
            printing: { label: 'Printing', class: 'printing', icon: Printer },
            ready: { label: 'Ready', class: 'ready', icon: Package },
            completed: { label: 'Completed', class: 'completed', icon: CheckCircle },
            cancelled: { label: 'Cancelled', class: 'cancelled', icon: XCircle }
        }
        const config = statusConfig[status] || { label: status, class: 'pending', icon: Clock }
        const Icon = config.icon
        return (
            <span className={`status-badge ${config.class}`}>
                <Icon size={14} />
                {config.label}
            </span>
        )
    }

    const getNextStatus = (currentStatus) => {
        const workflow = {
            pending: { next: 'processing', label: 'Start Processing' },
            processing: { next: 'printing', label: 'Start Printing' },
            printing: { next: 'ready', label: 'Mark Ready' },
            ready: { next: 'completed', label: 'Complete' }
        }
        return workflow[currentStatus]
    }

    const formatDate = (dateString) => {
        const date = new Date(dateString)
        return date.toLocaleString('en-IN', {
            day: '2-digit',
            month: 'short',
            hour: '2-digit',
            minute: '2-digit'
        })
    }

    const getTabCount = (tabId) => {
        if (tabId === 'all') return orders.length
        if (tabId === 'pending') return orders.filter(o => o.status === 'pending').length
        if (tabId === 'processing') return orders.filter(o => o.status === 'processing' || o.status === 'printing').length
        if (tabId === 'ready') return orders.filter(o => o.status === 'ready').length
        if (tabId === 'completed') return orders.filter(o => o.status === 'completed' || o.status === 'cancelled').length
        return 0
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
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '24px' }}>
                <div>
                    <h1 style={{ fontSize: '24px', fontWeight: '700', marginBottom: '4px' }}>Orders</h1>
                    <p style={{ color: 'var(--text-secondary)', fontSize: '14px' }}>
                        Manage and process print orders
                    </p>
                </div>
                <div className="live-indicator">
                    <span className="live-dot"></span>
                    Live Updates
                </div>
            </div>

            {/* Search and Filters */}
            <div style={{ display: 'flex', gap: '16px', marginBottom: '20px', flexWrap: 'wrap' }}>
                <div className="search-box" style={{ flex: 1, maxWidth: '360px' }}>
                    <Search size={18} />
                    <input
                        type="text"
                        className="form-input"
                        placeholder="Search by Order ID, Student name, or Roll number..."
                        value={searchQuery}
                        onChange={(e) => setSearchQuery(e.target.value)}
                    />
                </div>
                <button className="btn btn-secondary" onClick={fetchOrders}>
                    <RefreshCw size={16} />
                    Refresh
                </button>
            </div>

            {/* Tabs */}
            <div className="tabs">
                {tabs.map(tab => (
                    <button
                        key={tab.id}
                        className={`tab ${activeTab === tab.id ? 'active' : ''}`}
                        onClick={() => setActiveTab(tab.id)}
                    >
                        {tab.label} ({getTabCount(tab.id)})
                    </button>
                ))}
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
                <div className="orders-list">
                    {filteredOrders.map(order => {
                        const nextAction = getNextStatus(order.status)
                        return (
                            <div key={order.id} className="order-card">
                                <div
                                    className={`order-priority ${order.status}`}
                                ></div>

                                <div className="order-main">
                                    <div>
                                        <div className="order-id">{order.order_id}</div>
                                        <div className="order-date">{formatDate(order.created_at)}</div>
                                    </div>

                                    <div className="order-student">
                                        <h4>{order.students?.name || 'Unknown Student'}</h4>
                                        <span>{order.students?.roll_number} • {order.students?.dept}</span>
                                    </div>

                                    <div className="order-details">
                                        <span className="detail-tag">
                                            <Copy size={12} />
                                            {order.copies || 1} {order.copies === 1 ? 'copy' : 'copies'}
                                        </span>
                                        <span className="detail-tag">
                                            <Palette size={12} />
                                            {order.is_color ? 'Color' : 'B&W'}
                                        </span>
                                        <span className="detail-tag">
                                            <BookOpen size={12} />
                                            {order.is_double_sided ? 'Double-sided' : 'Single-sided'}
                                        </span>
                                        <span className="detail-tag">
                                            <File size={12} />
                                            {order.paper_size || 'A4'}
                                        </span>
                                    </div>

                                    <div className="order-amount">₹{Number(order.cost).toLocaleString()}</div>

                                    {getStatusBadge(order.status)}

                                    <div className="order-actions">
                                        {nextAction && (
                                            <button
                                                className="btn btn-primary btn-sm"
                                                onClick={() => updateOrderStatus(order.id, nextAction.next)}
                                                disabled={updatingOrder === order.id}
                                            >
                                                {updatingOrder === order.id ? 'Updating...' : nextAction.label}
                                            </button>
                                        )}

                                        {order.status === 'pending' && (
                                            <button
                                                className="btn btn-danger btn-sm"
                                                onClick={() => updateOrderStatus(order.id, 'cancelled')}
                                                disabled={updatingOrder === order.id}
                                            >
                                                Cancel
                                            </button>
                                        )}
                                    </div>
                                </div>
                            </div>
                        )
                    })}
                </div>
            )}
        </div>
    )
}
