extension MySQLPacket {
    public init(_ handshake: HandshakeResponse) {
        self.payload = ByteBufferAllocator().buffer(capacity: 0)
        handshake.serialize(into: &self.payload)
    }
    
    /// Protocol::HandshakeResponse
    ///
    /// Depending on the servers support for the CLIENT_PROTOCOL_41 capability and the clients
    /// understanding of that flag the client has to send either a Protocol::HandshakeResponse41
    /// or Protocol::HandshakeResponse320.
    ///
    /// Handshake Response Packet sent by 4.1+ clients supporting CLIENT_PROTOCOL_41 capability,
    /// if the server announced it in its Initial Handshake Packet. Otherwise (talking to an old server)
    /// the Protocol::HandshakeResponse320 packet must be used.
    ///
    /// https://dev.mysql.com/doc/internals/en/connection-phase-packets.html#packet-Protocol::HandshakeResponse
    public struct HandshakeResponse {
        /// capability_flags (4)
        /// capability flags of the client as defined in Protocol::CapabilityFlags
        public var capabilities: MySQLCapabilityFlags
        
        /// max_packet_size (4)
        /// max size of a command packet that the client wants to send to the server
        public var maxPacketSize: UInt32
        
        /// character_set (1)
        /// connection's default character set as defined in Protocol::CharacterSet.
        public var characterSet: MySQLCharacterSet
        
        /// username (string.fix_len)
        /// name of the SQL account which client wants to log in this string should be interpreted using the character set indicated by character set field.
        public var username: String
        
        /// auth-response (string.NUL)
        /// opaque authentication response data generated by Authentication Method indicated by the plugin name field.
        public var authResponse: ByteBuffer
        
        /// database (string.NUL)
        /// initial database for the connection -- this string should be interpreted using the character set indicated by character set field.
        public var database: String
        
        /// auth plugin name (string.NUL)
        /// the Authentication Method used by the client to generate auth-response value in this packet. This is an UTF-8 string.
        public var authPluginName: String
        
        /// Creates a new `MySQLHandshakeResponse41`
        public init(
            capabilities: MySQLCapabilityFlags,
            maxPacketSize: UInt32,
            characterSet: MySQLCharacterSet,
            username: String,
            authResponse: ByteBuffer,
            database: String,
            authPluginName: String
        ) {
            self.capabilities = capabilities
            self.maxPacketSize = maxPacketSize
            self.characterSet = characterSet
            self.username = username
            self.authResponse = authResponse
            self.database = database
            self.authPluginName = authPluginName
        }
        
        /// Serializes the `MySQLHandshakeResponse41` into a buffer.
        func serialize(into buffer: inout ByteBuffer) {
            buffer.writeInteger(self.capabilities.general, endianness: .little)
            buffer.writeInteger(maxPacketSize, endianness: .little)
            self.characterSet.serialize(into: &buffer)
            /// string[23]     reserved (all [0])
            buffer.writeBytes([
                0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
            ])
            buffer.writeNullTerminatedString(username)
            assert(self.capabilities.contains(.CLIENT_PLUGIN_AUTH_LENENC_CLIENT_DATA) == false, "CLIENT_PLUGIN_AUTH_LENENC_CLIENT_DATA not supported")
            if self.capabilities.contains(.CLIENT_SECURE_CONNECTION) {
                assert(authResponse.readableBytes <= UInt8.max, "auth response too large")
                buffer.writeInteger(UInt8(authResponse.readableBytes), endianness: .little)
                var authResponseCopy = self.authResponse
                buffer.writeBuffer(&authResponseCopy)
            } else {
                var authResponseCopy = self.authResponse
                buffer.writeBuffer(&authResponseCopy)
                // null terminated
                buffer.writeInteger(0, as: UInt8.self)
            }
            if self.capabilities.contains(.CLIENT_CONNECT_WITH_DB) {
                buffer.writeNullTerminatedString(self.database)
            } else {
                assert(self.database == "", "CLIENT_CONNECT_WITH_DB not enabled")
            }
            if self.capabilities.contains(.CLIENT_PLUGIN_AUTH) {
                buffer.writeNullTerminatedString(self.authPluginName)
            } else {
                assert(self.authPluginName == "", "CLIENT_PLUGIN_AUTH not enabled")
            }
            assert(self.capabilities.contains(.CLIENT_CONNECT_ATTRS) == false, "CLIENT_CONNECT_ATTRS not supported")
        }
    }
}
